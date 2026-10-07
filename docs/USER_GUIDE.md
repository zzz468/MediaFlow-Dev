# MediaFlow v0.7.0 User Guide

## Supported Platforms

Windows and Android are the supported release platforms. iOS, macOS and Linux retain architecture extension paths; Processing is not supported or release-validated on those platforms. Consult the v0.7.0 release record and RC report for artifacts, licenses and the actual acceptance scope.

## Windows Installation

1. Download and verify `MediaFlow-v0.7.0-windows-x64.zip`.
2. Extract the complete ZIP archive.
3. Run `MediaFlow.exe` from the extracted directory.
4. If Windows reports missing MSVC runtime files, install Microsoft Visual C++ Redistributable 2015-2022 x64.

Completed downloads are stored in the configured download directory. The default location is the user's Windows Downloads folder under `MediaFlow`.

## Android Installation

1. Install the signed `MediaFlow-v0.7.0-android.apk` without uninstalling or clearing a compatible existing installation.
2. Open MediaFlow and allow the installation to finish normally.
3. Completed downloads are published to `Download/MediaFlow/` through Android MediaStore.
4. Files are visible to the system file manager and video player.

## Basic Usage

1. Copy a supported public media link.
2. Paste it on the MediaFlow home page.
3. Select **Parse Link**.
4. Review the title, author, cover, duration, and download availability.
5. Add the item to the download queue when a media URL is available.
6. Use the Downloads page to pause, continue, retry, or remove tasks.

Supported link types include:

- Bilibili standard video links
- Bilibili `b23.tv` short sharing links
- Douyin `v.douyin.com` short sharing links
- Xiaohongshu public video and static gallery links
- YouTube watch, youtu.be and Shorts links
- Instagram public Post/Reel links, including ordered image/video Carousels
- X/Twitter public status links with images, video or ordered mixed media

For YouTube, the default selects the highest actual resolution that the complete production pipeline supports, then compares fps and bitrate. Compatible H.264 video-only + AAC audio-only downloads merge automatically into one MP4; History shows the final file. Manual quality and audio-only choices remain available. Some higher-resolution streams use VP9/AV1: this version does not transcode them, so final quality can be below the platform's maximum. It does not promise 4K output for every 4K upload. Douyin galleries may require a user-authorized normal login within MediaFlow's isolated session. Other platforms do not import browser cookies.

## Local Media Processing

Select a local file on the Media Processing page; Android uses the system document picker. The page shows the real codecs and each operation's availability/reason.

- **Trim:** fast stream-copy into MP4. The starting position may be affected by video keyframes; this is not frame-accurate editing.
- **Extract audio:** direct AAC extraction into M4A, without audio re-encoding or arbitrary codec conversion.
- **Extract frame:** JPEG at a specified time, available only when the current platform/device can decode the video.
- **HEVC:** availability depends on the operation and platform/device. The tested Windows runtime supports HEVC trim and AAC extraction but has no HEVC frame decoder. The tested Android device supports all three; other devices use capability results.
- **HDR/Dolby Vision:** encoded video packets can remain unchanged while some advanced dynamic HDR/Dolby Vision metadata is not fully preserved. Complete Dolby Vision preservation is not promised.

Outputs have a separate Processing History. Existing files and original input are not overwritten; validation and publication happen before success. Progress uses actual processing timestamps; frame extraction remains indeterminate. Android blocking frame cancellation is cooperative and may take time to settle. Interrupted processing is not resumed across an app/process restart.

## Windows FFmpeg Notices and Corresponding Source

The Windows ZIP includes the fixed FFmpeg 8.1.3 shared runtime under LGPL-2.1-or-later, with copyright, license, source and replacement information in `licenses/ffmpeg/`. The matching `MediaFlow-v0.7.0-ffmpeg-source-compliance.zip` must be provided as a separate release asset alongside the Windows ZIP. Stop MediaFlow before replacing a compatible runtime set; keep the original executable/DLL names and compatible ABI. MediaFlow does not lock replacement by binary hash at runtime. Android does not include FFmpeg. This notice is not a legal opinion.

## Pause, Resume, and History

- Active downloads can be paused and continued.
- HTTP Range and `.part` files protect resumable downloads when supported by the server.
- Download history is stored locally.
- Existing resumable tasks retain their resume behavior. YouTube temporary media addresses are not persisted; an unfinished YouTube, Instagram or X download after restart requires parsing the source link again. Completed local files remain in History.

## File Names

MediaFlow removes characters that are invalid on Windows or Android file systems. If a parsed title is empty or cannot form a safe file name, the app uses a stable fallback such as `Douyin Video` or `Untitled Video`.

## Local Data

MediaFlow stores settings, history, and logs locally. Cache cleanup removes logs and temporary files only. It does not remove completed media or download history.

## Legal Notice

MediaFlow does not bypass authentication, payment, regional, or permission restrictions. Users are responsible for following platform terms and copyright laws.
