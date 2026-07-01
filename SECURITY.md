# Security & Privacy

## Privacy model

Parley is built to be **fully local**. Your recordings and transcripts stay on your machine:

- Audio is transcribed on your own GPU via WhisperX / Whisper — it is **never uploaded**.
- The only outbound network activity is a **one-time download of the models** from Hugging Face, plus
  the license-gate check tied to your access token. No call audio or transcript is sent anywhere.
- `.env` (your Hugging Face token) and everything under `transcripts/` are **git-ignored**, so they
  can't be committed by accident.

If you want to double-check, run Parley with your network monitor open — after the initial model
download, transcription runs offline.

## Reporting a vulnerability

If you find a security issue, please **do not open a public issue**. Email
**kadyrov.dev@gmail.com** with details and steps to reproduce, and I'll acknowledge within a few days.

## Supported versions

This is a small personal project; fixes land on the `main` branch. Please test against the latest
commit before reporting.
