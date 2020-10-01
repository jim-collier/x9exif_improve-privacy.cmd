@echo off
SETLOCAL
goto :Start


::	Purpose:
::		- Tries to pseudo-anonymize image metadata (EXIF, XMP, and IPTC).
::		- Does not remove important stuff like title, author, copyright, keywords, camera metadata, etc.
::	History:
::		- 20200920 JC: Created.


:Start

	:: Constants
	set thisVersion=1.0.0

	:: Constant: useMethod:
	::     1 = Removes all invalid tags, then specifically named tags (two passes).
	::         Potentially not as thorough.
	::     2 = Removes all tags, except specifically named tags (one pass).
	::         WARNING: REMOVES IMPORTANT IPTC FIELDS (as an unfortunate side-effect of removing XMP-photoshop).
	set useMethod=1

	:: Args
	set argDir=%~1
	set argFileExtFlags=%~2

	:: Init
	set doCancel=0
	set progArgs_Common_First=
	set progArgs_Middle=
	set progArgs_Common_Last=
	set progArgs_Method1_Pass1=
	set progArgs_Method1_Pass2=
	set progArgs_Method2=
	if "%argDir%" == "" set argDir=.

	echo:
	echo This script attempts to pseudo-anonymize image metadata (EXIF, XMP, and IPTC).
	echo It does this by removing history, camera model, and GPS-related fields.
	echo It doesn't remove title, author, copyright, keywords, and similar basic fields.
	echo It relies on the program 'exiftool' being located in the environment path.
	if "%useMethod%" == "1" echo Tags to remove can be adjusted in the ':Metadata_RemoveSpecific' section.
	if "%useMethod%" == "2" echo Tags to keep can be adjusted in the ':Metadata_RemoveAllButSpecific' section.
	echo Run with '/?', '-h', or '--help' for syntax help.

	echo:
	echo %~n0 version %thisVersion%
	echo Copyright (c) 2020 James Collier.
	echo License GPLv3+: GNU GPL version 3 or later, full text at:
	echo https://www.gnu.org/licenses/gpl-3.0.en.html
	echo There is no warranty, to the extent permitted by law.
	echo:

	:: Validate
	call :MustBeInPath "exiftoolx" && if "%doCancel%" == "1" goto :Error
	if /i "%argDir%" == "/?"         echo Syntax:                              && goto :Syntax
	if /i "%argDir%" == "/h"         echo Syntax:                              && goto :Syntax
	if /i "%argDir%" == "/help"      echo Syntax:                              && goto :Syntax
	if /i "%argDir%" == "-h"         echo Syntax:                              && goto :Syntax
	if /i "%argDir%" == "-help"      echo Syntax:                              && goto :Syntax
	if /i "%argDir%" == "--help"     echo Syntax:                              && goto :Syntax
	if not exist "%argDir%"          echo Error: Folder not found: '%argDir%'  && goto :Syntax
	if "%argDir%" == "*.*"           echo Error: Don't use '*.*'.              && goto :Syntax
	if "%argDir%" == "*"             echo Error: Don't use '*'.                && goto :Syntax
	if "%argFileExtFlags%" == "*.*"  echo Error: Don't use '*.*'.              && goto :Syntax
	if "%argFileExtFlags%" == "*"    echo Error: Don't use '*'.                && goto :Syntax
	if "%useMethod%" == "1" goto :Start_Validate_OK010
	if "%useMethod%" == "2" goto :Start_Validate_OK010
		set errMsg=Internal bug: variable 'useMethod' should be between 1 or 2; instead got '%useMethod%'.
		goto :Error
	:Start_Validate_OK010

	:: Define metadata either by 'remove specific attributes', OR 'remove all EXCEPT specific attributes'
	:: Only use one, comment out the other.
	if "%useMethod%" == "1" call :Metadata_RemoveSpecific
	if "%useMethod%" == "2" call :Metadata_RemoveAllButSpecific


	::
	:: First group of options
	::

	:: Read all occurrences of duplicate tags.
	set progArgs_Common_Beginning=%progArgs_Common_Beginning%-a

	:: Brute-force XMP scan (should be fine without this flag)
	set progArgs_Common_Beginning=%progArgs_Common_Beginning% -scanForXMP

	:: Read unknown tags (which won't necessarily write them back)
	set progArgs_Common_Beginning=%progArgs_Common_Beginning% -unknown
	set progArgs_Common_Beginning=%progArgs_Common_Beginning% -unknown2

	::
	:: Last group of options
	::

	:: Overwrite existing file (in-place so that things like nodeid are preserved)
	set progArgs_Common_Last=%progArgs_Common_Last% -overwrite_original_in_place
::	set progArgs_Common_Last=%progArgs_Common_Last% -overwrite_original

	:: Console output options
	set progArgs_Common_Last=%progArgs_Common_Last% -ignoreMinorErrors
	set progArgs_Common_Last=%progArgs_Common_Last% -progress

	:: File specification (do last)
	if "%argFileExtFlags%" NEQ "" set progArgs_Common_Last=%progArgs_Common_Last% %argFileExtFlags%
	set progArgs_Common_Last=%progArgs_Common_Last% "%argDir%"

	::
	:: Show information to user (before prompting to continue later).
	::

	echo:
	echo FYI: ExifTool version (written for 12.06, latest as of 2020-09-20):
	exiftool -ver
	echo:
	echo Going to execute:

	::
	:: Build options depending on method ...
	::

	:: Build command strings
	goto :Main_010_Method%useMethod%

	:: Method 1: Two-passes to remove invalid tags, then specific tags
	:Main_010_Method1

		:: Calculate Pass 1 args (remove invalid tags).

			:: Standard first options
			set progArgs_Method1_Pass1=%progArgs_Common_Beginning%

			:: Remove potentially large, non-standard preview images, and unnecessary embedded thumbnail
			set progArgs_Method1_Pass1=%progArgs_Method1_Pass1% -trailer:all=
			set progArgs_Method1_Pass1=%progArgs_Method1_Pass1% -ThumbnailImage=

			:: Remove all tags; add only recognized standard tags back in.
			:: exiftool shortcuts '-unsafe' and '-icc_profile' are necessary so that the image still works.
			set progArgs_Method1_Pass1=%progArgs_Method1_Pass1% -all= -tagsfromfile @ -all:all -unsafe -icc_profile

			:: Standard last options
			set progArgs_Method1_Pass1=%progArgs_Method1_Pass1% %progArgs_Common_Last%

		:: Calculate pass 2 args (remove specific tags but leave everything else)

			call :Metadata_RemoveSpecific
			set progArgs_Method1_Pass2=%progArgs_Common_Beginning% %progArgs_Middle% %progArgs_Common_Last%

		:: Show info to user
		echo:
		echo Pass 1 (remove all non-standard tags):
		echo exiftool %progArgs_Method1_Pass1%
		echo:
		echo Pass 2 (remove specific privacy-related tags):
		echo exiftool %progArgs_Method1_Pass2%

		goto :Main_010_End

	:: Method 2: Remove ALL tags, except specific ones
	:Main_010_Method2

		:: Beginning args
		set progArgs_Method2=%progArgs_Common_Beginning%

		:: Remove potentially large, non-standard preview images, and unnecessary embedded thumbnail
		set progArgs_Method2=%progArgs_Method2% -trailer:all=
		set progArgs_Method2=%progArgs_Method2% -ThumbnailImage=

		:: exiftool shortcuts '-unsafe' and '-icc_profile' are necessary so that the image still works.
		set progArgs_Method2=%progArgs_Method2% -all= -tagsfromfile @ -unsafe -icc_profile

		:: Everything after that ('-tagsfromfile @') will be added back in
		call :Metadata_RemoveAllButSpecific
		set progArgs_Method2=%progArgs_Method2% %progArgs_Middle%

		:: Common last options
		set progArgs_Method2=%progArgs_Method2% %progArgs_Common_Last%

		:: Show info to user
		echo:
		echo exiftool %progArgs_Method2%

		goto :Main_010_End

	:Main_010_End

	::
	:: Prompt user to continue
	::

	echo:
	echo Press any key to continue, or CTRL+Break to abort ...
	pause >NUL
	echo:

	::
	:: Make it so
	::

	goto :Main_020_Method%useMethod%

	:: Method 1: Remove invalid tags, and specific tags
	:Main_020_Method1

		echo [ Pass 1 - remove all non-standard tags and other cruft ... ]
		echo:
		exiftool %progArgs_Method1_Pass1%
		echo:

		echo [ Pass 2 - remove specific tags ... ]
		echo:
		exiftool %progArgs_Method1_Pass2%

		goto :Main_020_End

	:: Method 2: Remove ALL tags, except specific ones
	:Main_020_Method2

		echo [ Removing all tags (including non-standard ones) except specific ones, and other cruft ... ]
		echo:
		exiftool %progArgs_Method2%

		goto :Main_020_End

	:Main_020_End

	echo:
	echo [ Done. ]

goto :EOF


:BuildCmd_AddField
	if "%~2" == "" goto :BuildCmd_AddField_NoArg2
		if "%progArgs_Middle%" NEQ "" set progArgs_Middle=%progArgs_Middle% -"%~1:%~2"=
		if "%progArgs_Middle%" EQU "" set progArgs_Middle="-%~1:%~2="
		goto :EOF
	:BuildCmd_AddField_NoArg2
		if "%progArgs_Middle%" NEQ "" set progArgs_Middle=%progArgs_Middle% -"%~1"=
		if "%progArgs_Middle%" EQU "" set progArgs_Middle=-"%~1"=
goto :EOF


:: New version puts quotes around everything (required for flags with "*" but just do for all).
:BuildCmd_AddField_DEPRECATED
	if "%~2" == "" goto :BuildCmd_AddField_NoArg2
		if "%progArgs_Middle%" NEQ "" set progArgs_Middle=%progArgs_Middle% -%~1:%~2=
		if "%progArgs_Middle%" EQU "" set progArgs_Middle=-%~1:%~2=
		goto :EOF
	:BuildCmd_AddField_NoArg2
		if "%progArgs_Middle%" NEQ "" set progArgs_Middle=%progArgs_Middle% -%~1=
		if "%progArgs_Middle%" EQU "" set progArgs_Middle=-%~1=
goto :EOF


:Metadata_RemoveSpecific

	:: Define metadata fields to clear
	call :BuildCmd_AddField  Adobe
	call :BuildCmd_AddField  all                  *Aperture*
	call :BuildCmd_AddField  all                  *DocumentID
	call :BuildCmd_AddField  all                  *Exposure*
	call :BuildCmd_AddField  all                  *FileName*
	call :BuildCmd_AddField  all                  *FNumber*
	call :BuildCmd_AddField  all                  *FocalLength*
	call :BuildCmd_AddField  all                  *History*
	call :BuildCmd_AddField  all                  *InstanceID
	call :BuildCmd_AddField  all                  *LastURL
	call :BuildCmd_AddField  all                  *Lens*
	call :BuildCmd_AddField  all                  *Metering*
	call :BuildCmd_AddField  all                  *Serial*
	call :BuildCmd_AddField  all                  *ShutterSpeed*
	call :BuildCmd_AddField  all                  *Thumbnail*
	call :BuildCmd_AddField  all                  *UniqueID
	call :BuildCmd_AddField  all                  Derived*
	call :BuildCmd_AddField  all                  GPS*
	call :BuildCmd_AddField  all                  Software
	call :BuildCmd_AddField  Common
	call :BuildCmd_AddField  CommonIFD0
	call :BuildCmd_AddField  MakerNotes
	call :BuildCmd_AddField  XMP                  CreatorTool
	call :BuildCmd_AddField  XMP                  DocumentAncestors
	call :BuildCmd_AddField  XMP-crs              all
	call :BuildCmd_AddField  XMP-expressionmedia  all
	call :BuildCmd_AddField  XMP-extensis         all
	call :BuildCmd_AddField  XMP-getty            all
	call :BuildCmd_AddField  XMP-microsoft        all
	call :BuildCmd_AddField  XMP-photoshop        all
	call :BuildCmd_AddField  XMP-xmpMM            all

	:: Unnecessary
::	call :BuildCmd_AddField  all                  Camera*
::	call :BuildCmd_AddField  all                  DerivedFrom
::	call :BuildCmd_AddField  all                  DerivedFromDocumentID
::	call :BuildCmd_AddField  all                  DerivedFromInstanceID
::	call :BuildCmd_AddField  all                  DerivedFromLastURL
::	call :BuildCmd_AddField  all                  DerivedFromOriginalDocumentID
::	call :BuildCmd_AddField  all                  DocumentID
::	call :BuildCmd_AddField  all                  FileName
::	call :BuildCmd_AddField  all                  Flash*
::	call :BuildCmd_AddField  all                  HistoryAction
::	call :BuildCmd_AddField  all                  HistoryChanged
::	call :BuildCmd_AddField  all                  HistoryInstanceID
::	call :BuildCmd_AddField  all                  HistoryParameters
::	call :BuildCmd_AddField  all                  HistorySoftwareAgent
::	call :BuildCmd_AddField  all                  HistoryWhen
::	call :BuildCmd_AddField  all                  ManagedFromLastURL
::	call :BuildCmd_AddField  all                  MaxAperture*
::	call :BuildCmd_AddField  all                  OriginalDocumentID
::	call :BuildCmd_AddField  all                  OriginalFileName
::	call :BuildCmd_AddField  all                  RawFileName
::	call :BuildCmd_AddField  all                  Scene*
::	call :BuildCmd_AddField  all                  Serial*
::	call :BuildCmd_AddField  Canon
::	call :BuildCmd_AddField  Nikon
::	call :BuildCmd_AddField  XMP                  HistoryAction
::	call :BuildCmd_AddField  XMP                  OriginalDocumentID
::	call :BuildCmd_AddField  XMP                  Software
::	call :BuildCmd_AddField  XMP-xmpMM            DerivedFrom
::	call :BuildCmd_AddField  XMP-xmpMM            DerivedFromDocumentID
::	call :BuildCmd_AddField  XMP-xmpMM            DerivedFromInstanceID
::	call :BuildCmd_AddField  XMP-xmpMM            DerivedFromLastURL
::	call :BuildCmd_AddField  XMP-xmpMM            DerivedFromOriginalDocumentID
::	call :BuildCmd_AddField  XMP-xmpMM            DocumentID
::	call :BuildCmd_AddField  XMP-xmpMM            HistoryAction
::	call :BuildCmd_AddField  XMP-xmpMM            HistoryChanged
::	call :BuildCmd_AddField  XMP-xmpMM            HistoryInstanceID
::	call :BuildCmd_AddField  XMP-xmpMM            HistoryParameters
::	call :BuildCmd_AddField  XMP-xmpMM            HistorySoftwareAgent
::	call :BuildCmd_AddField  XMP-xmpMM            HistoryWhen
::	call :BuildCmd_AddField  XMP-xmpMM            InstanceID
::	call :BuildCmd_AddField  XMP-xmpMM            LastURL
::	call :BuildCmd_AddField  XMP-xmpMM            ManagedFromLastURL
::	call :BuildCmd_AddField  XMP-xmpMM            OriginalDocumentID

goto :EOF


:Metadata_RemoveAllButSpecific

	:: Everything from here (after '-tagsFromFile @') is now an explicit EXCEPT list.
	call :BuildCmd_AddField  XMP                  Rating
	call :BuildCmd_AddField  XMP                  CreateDate
	call :BuildCmd_AddField  XMP                  ModifyDate
	call :BuildCmd_AddField  XMP-xmp              Title
	call :BuildCmd_AddField  XMP-dc               Creator
	call :BuildCmd_AddField  XMP-dc               Contributor
	call :BuildCmd_AddField  XMP-dc               Subject
	call :BuildCmd_AddField  XMP-dc               Rights
	call :BuildCmd_AddField  XMP-dc               Description
	call :BuildCmd_AddField  XMP-dc               Language
	call :BuildCmd_AddField  XMP-photoshop        AuthorsPosition
	call :BuildCmd_AddField  XMP-photoshop        CaptionWriter
	call :BuildCmd_AddField  XMP-photoshop        Credit
	call :BuildCmd_AddField  XMP-photoshop        Source
	call :BuildCmd_AddField  XMP-photoshop        Headline
	call :BuildCmd_AddField  XMP-photoshop        Instructions
	call :BuildCmd_AddField  XMP-xmpRights        Marked
	call :BuildCmd_AddField  XMP-xmpRights        WebStatement
	call :BuildCmd_AddField  XMP-iptcCore         CreatorAddress
	call :BuildCmd_AddField  XMP-iptcCore         CreatorWorkURL

goto :EOF


:MustBeInPath
	if not "%~$PATH:1"=="" goto :EOF
		set doCancel=1
		set errMsg=The executable '%~1' is required to be in the path, but doesn't seem to be.
goto :EOF

:Syntax
	echo:
	echo - Argument 1   [optional]: Folder to process (defaults to current).
	echo - Argument 2-N [optional]: One or more '-ext SSS' to specify file types
	echo -                          to process. Defaults to all supported.
	goto :End
goto :EOF

:Trim
		set %~1=%~2
goto :EOF

:Error
	set doCancel=1
	echo:
	if "%errMsg%" == "" goto :Error_Empty
		echo Error: %errMsg%
		goto :Error_X
	:Error_Empty
		echo An error occurred.
	:Error_X
	pause
	goto :End
:goto :EOF

:End
	ENDLOCAL
goto :EOF
