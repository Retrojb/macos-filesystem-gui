# Requirements Document

## Introduction

The Media Preview Viewer provides inline preview capability for video and photo files within the RetroFilesystemGUI application. Users can view photos immediately and watch videos with explicit playback controls. Videos follow a privacy-respecting pattern: they never auto-play and always start muted when manually triggered, giving users full control over audio output.

## Glossary

- **Preview_Viewer**: The UI component responsible for displaying media previews of selected files within the application
- **Media_File**: A file identified as either a photo or video based on its Uniform Type Identifier (UTI)
- **Photo_File**: A media file conforming to a supported image UTI (e.g., JPEG, PNG, HEIC, TIFF, GIF, WebP)
- **Video_File**: A media file conforming to a supported video UTI (e.g., MP4, MOV, AVI, MKV, WebM)
- **Video_Thumbnail**: A static image representation of a video file, typically the first frame or a system-generated preview
- **Playback_Controls**: The set of UI controls overlaid on a video preview, including play/pause and mute/unmute buttons
- **Mute_State**: A boolean state indicating whether audio output is suppressed during video playback

## Requirements

### Requirement 1: Photo Preview Display

**User Story:** As a user, I want to see an immediate preview of photo files when I select them, so that I can quickly identify image content without opening a separate application.

#### Acceptance Criteria

1. WHEN a Photo_File is selected, THE Preview_Viewer SHALL display the full image content of the selected file within 1 second of selection
2. WHEN a Photo_File is selected, THE Preview_Viewer SHALL render the image scaled to fit within the preview area while maintaining the original aspect ratio, without cropping or distorting the image
3. IF a Photo_File cannot be loaded or is corrupted, THEN THE Preview_Viewer SHALL display an error indicator in place of the image and SHALL NOT display any previously loaded image content
4. WHEN a different Photo_File is selected while a preview is already displayed, THE Preview_Viewer SHALL replace the current preview with the newly selected file's image content within 1 second

### Requirement 2: Video Thumbnail Display

**User Story:** As a user, I want to see a static thumbnail for video files when I select them, so that I can identify video content without triggering playback.

#### Acceptance Criteria

1. WHEN a Video_File is selected, THE Preview_Viewer SHALL display a Video_Thumbnail scaled to fit within the preview area while maintaining the original aspect ratio within 3 seconds of selection
2. WHEN a Video_File is selected, THE Preview_Viewer SHALL NOT initiate video playback automatically
3. WHEN a Video_File is selected, THE Preview_Viewer SHALL display a play button overlay centered on the Video_Thumbnail to indicate playback is available
4. IF a Video_Thumbnail cannot be generated within 5 seconds of selection, THEN THE Preview_Viewer SHALL display a generic video file icon in place of the thumbnail
5. WHEN a Video_File is selected while a previous preview is displayed, THE Preview_Viewer SHALL replace the previous preview content with the new Video_Thumbnail

### Requirement 3: Video Playback Initiation

**User Story:** As a user, I want to manually start video playback by pressing a play button, so that I have full control over when videos begin playing.

#### Acceptance Criteria

1. WHEN the user activates the play button on a Video_File preview, THE Preview_Viewer SHALL begin video playback within 3 seconds with Mute_State set to true
2. WHEN video playback begins, THE Preview_Viewer SHALL replace the Video_Thumbnail with the playing video content
3. WHEN video playback begins, THE Preview_Viewer SHALL display Playback_Controls overlaid on the video
4. IF the Video_File cannot be played after the user activates the play button, THEN THE Preview_Viewer SHALL display an error indicator in place of the video content and shall not leave the preview in a blank or loading state
5. WHEN the user selects a different file while video playback is active, THE Preview_Viewer SHALL stop the current video playback before displaying the newly selected file preview

### Requirement 4: Video Audio Control

**User Story:** As a user, I want to control whether video audio is active during playback, so that I can choose to hear audio only when appropriate.

#### Acceptance Criteria

1. WHILE a Video_File is playing, THE Preview_Viewer SHALL display a mute/unmute toggle within the Playback_Controls that visually indicates the current Mute_State
2. WHEN the user activates the unmute control, THE Preview_Viewer SHALL set Mute_State to false, update the toggle to indicate unmuted state, and output the video audio
3. WHEN the user activates the mute control, THE Preview_Viewer SHALL set Mute_State to true, update the toggle to indicate muted state, and suppress audio output
4. WHEN a new video playback session begins by user activation of the play button on any Video_File, THE Preview_Viewer SHALL set Mute_State to true regardless of the Mute_State value from any prior session
5. IF the user activates the unmute control on a Video_File that contains no audio track, THEN THE Preview_Viewer SHALL keep Mute_State set to true and continue displaying the muted indicator

### Requirement 5: Video Playback Control

**User Story:** As a user, I want to pause and resume video playback, so that I can control the viewing experience.

#### Acceptance Criteria

1. WHILE a Video_File is playing, THE Preview_Viewer SHALL display a pause button within the Playback_Controls
2. WHEN the user activates the pause button, THE Preview_Viewer SHALL pause video playback, display the current frame as a still image, and replace the pause button with a play button within the Playback_Controls
3. WHEN the user activates the play button on a paused video, THE Preview_Viewer SHALL resume playback from the paused position while preserving the current Mute_State
4. WHEN video playback reaches the end of the file, THE Preview_Viewer SHALL stop playback and display the Video_Thumbnail with the play button overlay
5. WHEN a different file is selected while a Video_File is playing or paused, THE Preview_Viewer SHALL stop the current video playback and release playback resources

### Requirement 6: Supported Media Type Detection

**User Story:** As a user, I want the preview viewer to automatically determine whether a selected file is a photo or video, so that the appropriate preview behavior is applied without manual intervention.

#### Acceptance Criteria

1. WHEN a file is selected, THE Preview_Viewer SHALL determine the media type by checking whether the file's Uniform Type Identifier conforms to a supported image or video UTI using the system UTI conformance hierarchy, completing the determination within 500 milliseconds of selection
2. WHEN the file's UTI conforms to any of the supported image types (public.jpeg, public.png, public.heic, public.tiff, com.compuserve.gif, public.webp), THE Preview_Viewer SHALL treat the file as a Photo_File
3. WHEN the file's UTI conforms to any of the supported video types (public.mpeg-4, com.apple.quicktime-movie, public.avi, public.webm), THE Preview_Viewer SHALL treat the file as a Video_File
4. IF the selected file does not conform to any supported image or video UTI, THEN THE Preview_Viewer SHALL display an empty preview area with no media content rendered and no error indicator
5. IF the selected file cannot be accessed or has no determinable UTI, THEN THE Preview_Viewer SHALL treat the file as unsupported and not render a media preview
