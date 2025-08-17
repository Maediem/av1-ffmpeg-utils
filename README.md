# FFmpeg AV1 & Opus Batch Encoder

A Bash script for batch-processing video files, converting video to the high-efficiency AV1 codec and audio to the modern Opus codec. It features an interactive setup, audio handling, container validation, and logging.

---

This repository includes two Bash scripts:

1. `install_ffmpeg.sh` – Installs FFmpeg to `/opt/ffmpeg`.
2. `ffmpeg_av1_encode.sh` – Encodes video files to AV1 using FFmpeg with customizable parameters like Opus codec.

---


## Requirements

- A **Linux-based operating system**.
  - **For Windows users**: You can use the **Windows Subsystem for Linux (WSL)** or a Virtual Machine (VM). Install a distribution like Ubuntu from the Microsoft Store to run the script.
- The following command-line tools must be installed:
  - `ffmpeg` & `ffprobe` (version 4.3 or newer recommended for good AV1 support)
  - `tput` (for colored output, usually installed by default)
  - `bc` (for floating-point math, usually installed by default)

---

## Why AV1?

AV1 is a modern, open-source video codec developed by the Alliance for Open Media (AOM), probably to be the successor to both H.264 (x264) and H.265 (HEVC/x265).


### Compression Efficiency

AV1 offers significantly better compression while maintaining the same visual quality:

- **Compared to x264 (H.264)**: AV1 is ~30–50% more efficient.
- **Compared to x265 (HEVC)**: AV1 is ~20–30% more efficient.
- As a general rule of thumb, AV1 CRF values are about 4 points higher than x265 for similar quality. For example, CRF 20 with AV1 is roughly equivalent to CRF 16 with x265.

This means smaller file sizes with equal or better video quality — ideal for archiving, streaming, and storage-limited environments.

### Royalty-Free & Open Source

One of AV1's biggest advantages is its **royalty-free license**, unlike H.264 and H.265, which require licensing fees and are governed by patent pools.

- No licensing fees for using, distributing, or implementing AV1.
- Easier adoption across platforms, software, and hardware.
- Supported by major tech companies like Google, Netflix, Amazon, and Mozilla.

### Future-Proof Format

- Supported in modern browsers (Chrome, Firefox, Edge).
- Used in platforms like YouTube, Netflix, and Vimeo.
- Continually improving with tools like SVT-AV1 for faster encoding.

In short: **AV1 delivers higher quality at smaller sizes, with no licensing headaches** — making it a smart choice for creators and developers alike.


---

## Why Opus?

Opus is a modern, highly versatile, open-source audio codec standardized by the Internet Engineering Task Force (IETF). It was designed to surpass existing codecs for everything from real-time speech to high-fidelity music and movie audio.

### Superior Compression Efficiency

Opus delivers higher perceived quality at lower bitrates than its predecessors, making it a very efficient lossy audio codec available today.

- **Compared to AAC/MP3**: Opus is often considered transparent for stereo audio around 96-128 kbps, a quality level that requires significantly higher bitrates from older codecs.
- **Compared to AC3/EAC3**: For surround sound, Opus at 480 kbps can be perceptually identical to EAC3 at 640 kbps, offering **~25% file size savings** for the audio track with no discernible loss in quality.

This means you can achieve transparent audio in a much smaller file, saving significant storage space in your media library.

### Royalty-Free & Open Source

Like AV1, Opus is completely **royalty-free**, removing the licensing complexities associated with codecs like AAC, AC3, and EAC3 (Dolby).

- No patent licensing fees for implementation or distribution.
- Universal adoption in web standards (WebRTC) and open-source projects.
- Used and supported by major companies like Google (YouTube, Meet), Mozilla, WhatsApp, and Discord.

In short: **Opus delivers transparent audio quality at smaller sizes, with incredible versatility and zero licensing fees** — making it the ideal choice for modern audio encoding.

---

## install_ffmpeg.sh – Install FFmpeg (AV1 & Opus Support)

This script builds FFmpeg from source and installs it to `/opt/ffmpeg`. It will also add it to your source so you can use the latest ffmpeg command available.

### Usage

```bash
chmod +x install_ffmpeg.sh
./install_ffmpeg.sh
```

You should see `libsvtav1` listed in the configuration output.

---

## Encode Files in AV1

This script uses the FFmpeg binary to encode video files in AV1 format with 10bits (`yuv420p10le`).

### Configuration

Before running the script, modify these two variables at the top:

```bash
DEFAULT_SRC_LOCATION="/path/to/your/source/directory"
DEFAULT_DST_LOCATION="/path/to/your/output/directory"
```

The script will search for all files inside the source directory based on the extension provided (e.g. `mkv`) and loop over them and write the output in the destination. The name should be very similar. It will replace the `x264`/`h264`/`hevc` with `AV1` or add `AV1` in the filename. 

### Usage

```bash
chmod +x ffmpeg_av1_encode.sh
./ffmpeg_av1_encode.sh
```

---

## Encoding Presets

The script includes two sets of AV1 encoding parameters optimized for either live-action or anime content.

---

## Tips

- Lower presets in AV1 encoding improve compression efficiency and visual quality — but take longer to encode.
- Lower CRF (Constant Rate Factor) values increase file size but preserve more detail, resulting in higher quality.
- Ensure your system has enough CPU threads; SVT-AV1 scales efficiently with multiple cores for faster encoding.



