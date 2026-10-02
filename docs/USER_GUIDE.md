# MediaFlow v0.5.0 User Guide

## Supported Platforms

The public beta has been validated on Windows 11 and an Android 16 USB-connected device.

## Windows Installation

1. Download and verify `MediaFlow-v0.5.0-windows-x64.zip`.
2. Extract the complete ZIP archive.
3. Run `MediaFlow.exe` from the extracted directory.
4. If Windows reports missing MSVC runtime files, install Microsoft Visual C++ Redistributable 2015-2022 x64.

Completed downloads are stored in the configured download directory. The default location is the user's Windows Downloads folder under `MediaFlow`.

## Android Installation

1. Install the signed `MediaFlow-v0.5.0-android.apk` without uninstalling a compatible existing installation.
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

Supported beta link types include:

- Bilibili standard video links
- Bilibili `b23.tv` short sharing links
- Douyin `v.douyin.com` short sharing links
- Xiaohongshu public video and static gallery links
- YouTube watch, youtu.be and Shorts links

For YouTube, select one quality/resource before downloading: 有声视频 includes picture and sound; 无声音 video and 仅音频 are independent files. MediaFlow does not merge tracks. Douyin galleries may require a user-authorized normal login within MediaFlow's isolated session. Other platforms do not import browser cookies.

## Pause, Resume, and History

- Active downloads can be paused and continued.
- HTTP Range and `.part` files protect resumable downloads when supported by the server.
- Download history is stored locally.
- Existing resumable tasks retain their resume behavior. YouTube temporary media addresses are not persisted; an unfinished YouTube download after restart requires parsing the source link again. Completed local files remain in History.

## File Names

MediaFlow removes characters that are invalid on Windows or Android file systems. If a parsed title is empty or cannot form a safe file name, the app uses a stable fallback such as `Douyin Video` or `Untitled Video`.

## Local Data

MediaFlow stores settings, history, and logs locally. Cache cleanup removes logs and temporary files only. It does not remove completed media or download history.

## Legal Notice

MediaFlow does not bypass authentication, payment, regional, or permission restrictions. Users are responsible for following platform terms and copyright laws.
