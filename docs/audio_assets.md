# Audio Asset Catalog & License Documentation

All audio diagnostic assets located in `frontend/assets/audio/` are algorithmically synthesized from first mathematical principles using `scripts/generate_audio_assets.py`. Zero copyrighted, sampled, or third-party audio recordings are included.

## License: Creative Commons Zero (CC0 1.0 Universal)

To the extent possible under law, the authors and contributors of Markazi System Checker have dedicated all copyright and related and neighboring rights to these audio assets to the public domain worldwide.

- **License URL**: https://creativecommons.org/publicdomain/zero/1.0/
- **Warranty**: These assets are provided "AS IS", without warranty of any kind.
- **Usage**: You can copy, modify, distribute, and perform the work, even for commercial purposes, all without asking permission.

---

## Audio Asset Catalog

| Filename | Freq / Signal Type | Channel Routing | Duration | Sample Rate | Bit Depth | Size (Bytes) | Diagnostic Purpose |
|---|---|---|---|---|---|---|---|
| `sine_440hz_left.wav` | 440 Hz Sine (Concert A4) | Left: Active, Right: Silent | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Left earphone driver isolation |
| `sine_440hz_right.wav` | 440 Hz Sine (Concert A4) | Left: Silent, Right: Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Right earphone driver isolation |
| `sine_440hz_both.wav` | 440 Hz Sine (Concert A4) | Left & Right Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Stereo concert pitch reference |
| `sine_1khz_left.wav` | 1000 Hz Sine (1 kHz) | Left: Active, Right: Silent | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Left earphone 1 kHz diagnostic |
| `sine_1khz_right.wav` | 1000 Hz Sine (1 kHz) | Left: Silent, Right: Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Right earphone 1 kHz diagnostic |
| `sine_1khz_both.wav` | 1000 Hz Sine (1 kHz) | Left & Right Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | 1 kHz standard reference |
| `bass_40hz.wav` | 40 Hz Sub-bass Sine | Left & Right Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Sub-bass driver extension |
| `bass_60hz.wav` | 60 Hz Bass Sine | Left & Right Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Low-bass punch & resonance |
| `bass_80hz.wav` | 80 Hz Upper-bass Sine | Left & Right Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Upper-bass frequency response |
| `bass_100hz.wav` | 100 Hz Mid-bass Sine | Left & Right Active | 2.5s | 44,100 Hz | 16-bit PCM | 441,044 | Mid-bass frequency response |
| `bass_sweep_20_120hz.wav` | 20 Hz to 120 Hz Log Sweep | Left & Right Active | 3.0s | 44,100 Hz | 16-bit PCM | 529,244 | Continuous bass driver sweep |
| `pink_noise.wav` | $1/f$ Pink Noise Spectral | Stereo Center | 3.0s | 44,100 Hz | 16-bit PCM | 529,244 | Full-spectrum headphone balance |
| `channel_id_chime.wav` | Sequenced Stereo Chime | L (C5, E5) $\to$ Silence $\to$ R (E5, G5) | 2.8s | 44,100 Hz | 16-bit PCM | 493,960 | Intuitive stereo orientation verification |

---

## Technical Specifications & Mathematical Synthesis

### 1. General PCM Audio Parameters
- **Audio Container**: RIFF WAVE (`WAVE_FORMAT_PCM`, format tag 1).
- **Channels**: 2 channels (stereo, interleaved $L_0, R_0, L_1, R_1, \dots$).
- **Sample Rate**: 44,100 Hz (CD audio standard).
- **Bit Depth**: 16 bits per sample (signed little-endian integers, range $-32768$ to $+32767$).
- **Peak Amplitude**: Normalized to $-1.4$ dBFS ($0.85$ peak level), preventing DAC inter-sample clipping.
- **Anti-Click Envelope**: 25ms raised-cosine / Hann window at onset and offset to eliminate transient DC clicks:
  $$w_{\text{onset}}(t) = 0.5 \left(1 - \cos\left(\frac{\pi t}{0.025}\right)\right), \quad t \in [0, 0.025]$$

### 2. Logarithmic Frequency Sweep ($20 \text{ Hz} \to 120 \text{ Hz}$)
Synthesized using an exponential instantaneous frequency trajectory, ensuring equal duration per musical octave:
$$f(t) = f_0 \left(\frac{f_1}{f_0}\right)^{t / T}, \quad k = \frac{\ln(f_1 / f_0)}{T}$$
$$\phi(t) = 2\pi \int_0^t f(\tau) d\tau = 2\pi f_0 \frac{\exp(k t) - 1}{k}$$
$$s(t) = 0.85 \cdot \sin(\phi(t))$$
Where $f_0 = 20\text{ Hz}$, $f_1 = 120\text{ Hz}$, $T = 3.0\text{ s}$.

### 3. Filtered Pink Noise ($1/f$ Spectral Density)
Synthesized via frequency-domain Fourier synthesis:
1. Standard normal white noise vector $w[n]$ generated with a deterministic PRNG seed.
2. Real Fast Fourier Transform: $X[k] = \text{FFT}(w[n])$.
3. Spectral $1/\sqrt{f}$ scaling applied to magnitudes for all non-zero frequency bins:
   $$H[k] = \frac{1}{\sqrt{f_k}} \quad (\text{with } H[0] = 0 \text{ to suppress DC offset})$$
4. Inverse Real FFT: $p[n] = \text{IRFFT}(X[k] \cdot H[k])$.
5. Peak normalization to $-1.4$ dBFS ($0.85$).

### 4. Sequenced Stereo Identification Chime
Constructed to verify left-right headphone orientation without requiring user technical training:
- **0.1s - 0.5s**: Left ear tone burst (523.25 Hz C5, Hann windowed, 400ms), Right ear silent.
- **0.6s - 1.0s**: Left ear tone burst (659.25 Hz E5, Hann windowed, 400ms), Right ear silent.
- **1.1s - 1.6s**: Inter-channel silence (500ms).
- **1.6s - 2.0s**: Right ear tone burst (659.25 Hz E5, Hann windowed, 400ms), Left ear silent.
- **2.1s - 2.5s**: Right ear tone burst (783.99 Hz G5, Hann windowed, 400ms), Left ear silent.

---

## Regeneration Command

To re-synthesize all audio assets identically:
```powershell
py -3 scripts/generate_audio_assets.py
```
