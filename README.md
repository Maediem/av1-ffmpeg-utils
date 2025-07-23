# FFmpeg AV1 Scripts

This repository includes two Bash scripts:

1. `install_ffmpeg.sh` – Installs FFmpeg to `/opt/ffmpeg`.
2. `ffmpeg_av1_encode.sh` – Encodes video files to AV1 using FFmpeg with few customizable parameters.

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

## install_ffmpeg.sh – Install FFmpeg with AV1 Support

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



