#!/bin/bash

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null; then
  echo "❌ yt-dlp is not installed. Please install it first:"
  echo "🔧 pip install yt-dlp"
  exit 1
fi

echo "======================================"
echo "       YouTube Downloader Tool"
echo "======================================"

# Prompt for URL
read -p "📺 Enter YouTube URL: " url

# Basic YouTube URL validation
if [[ ! $url =~ ^https?://(www\.)?(youtube\.com|youtu\.be)/ ]]; then
  echo "❌ Invalid YouTube URL."
  exit 1
fi

# Ask if it's a playlist or single video
echo ""
echo "📚 Is this a playlist or a single video?"
echo "1. Single video"
echo "2. Playlist"
read -p "Choose [1-2]: " is_playlist

if [[ "$is_playlist" == "2" ]]; then
  playlist_flag=""
else
  playlist_flag="--no-playlist"
fi

# Download type
echo ""
echo "📥 What would you like to download?"
echo "1. Full Video"
echo "2. Audio (MP3)"
echo "3. Audio (WAV)"
echo "4. Video Only (no audio)"
echo "5. Subtitles Only"
echo "6. Exit"
read -p "Choose [1-6]: " choice

case $choice in
  1)
    echo ""
    echo "🎞️  Choose video quality:"
    echo "1. Best available"
    echo "2. 1080p"
    echo "3. 720p"
    echo "4. 480p"
    echo "5. 360p"
    read -p "Choose [1-5]: " quality
    case $quality in
      1) format="bestvideo+bestaudio/best" ;;
      2) format="bestvideo[height<=1080]+bestaudio/best[height<=1080]" ;;
      3) format="bestvideo[height<=720]+bestaudio/best[height<=720]" ;;
      4) format="bestvideo[height<=480]+bestaudio/best[height<=480]" ;;
      5) format="bestvideo[height<=360]+bestaudio/best[height<=360]" ;;
      *) format="bestvideo+bestaudio/best" ;;
    esac
    yt-dlp -f "$format" --merge-output-format mp4 $playlist_flag "$url"
    ;;

  2)
    echo ""
    echo "🎧 Choose audio quality:"
    echo "1. Best"
    echo "2. 192 kbps"
    echo "3. 128 kbps"
    echo "4. 64 kbps"
    read -p "Choose [1-4]: " aquality
    case $aquality in
      1) aq="0" ;;        # best
      2) aq="192K" ;;
      3) aq="128K" ;;
      4) aq="64K" ;;
      *) aq="192K" ;;
    esac
    yt-dlp --extract-audio --audio-format mp3 --audio-quality "$aq" $playlist_flag "$url"
    ;;

  3)
    yt-dlp --extract-audio --audio-format wav $playlist_flag "$url"
    ;;

  4)
    echo ""
    echo "🎥 Choose video quality:"
    echo "1. Best"
    echo "2. 1080p"
    echo "3. 720p"
    echo "4. 480p"
    echo "5. 360p"
    read -p "Choose [1-5]: " vo_quality
    case $vo_quality in
      1) vformat="bestvideo" ;;
      2) vformat="bestvideo[height<=1080]" ;;
      3) vformat="bestvideo[height<=720]" ;;
      4) vformat="bestvideo[height<=480]" ;;
      5) vformat="bestvideo[height<=360]" ;;
      *) vformat="bestvideo" ;;
    esac
    yt-dlp -f "$vformat" $playlist_flag "$url"
    ;;

  5)
    yt-dlp --write-subs --sub-lang en.* --skip-download $playlist_flag "$url"
    ;;

  6)
    echo "👋 Goodbye!"
    exit 0
    ;;

  *)
    echo "❌ Invalid option. Exiting."
    exit 1
    ;;
esac
