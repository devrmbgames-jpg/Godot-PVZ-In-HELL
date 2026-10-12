"""Build the authored, original placeholder night motif; never run in gameplay."""

from array import array
from io import BytesIO
import math
from pathlib import Path
import sys
import wave

ROOT = Path(__file__).resolve().parent.parent
DESTINATION = ROOT / "content/domains/npc/presentation/night_presence.wav"
SAMPLE_RATE = 24000
DURATION = 12
NOTES = (55.0, 65.406, 61.735, 55.0)


def main() -> None:
    samples = array("h")
    for index in range(SAMPLE_RATE * DURATION):
        time = index / SAMPLE_RATE
        phrase_time = time % 3.0
        frequency = NOTES[min(int(time / 3.0), len(NOTES) - 1)]
        envelope = min(time / 0.5, (DURATION - time) / 0.5, 1.0)
        phrase = math.sin(math.pi * phrase_time / 3.0) ** 2
        drone = 0.075 * math.sin(math.tau * 55.0 * time)
        tone = phrase * (
            0.10 * math.sin(math.tau * frequency * time)
            + 0.025 * math.sin(math.tau * frequency * 2.0 * time)
        )
        samples.append(round((drone + tone) * envelope * 32767))
    if sys.byteorder != "little":
        samples.byteswap()
    stream = BytesIO()
    with wave.open(stream, "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(samples.tobytes())
    data = stream.getvalue()
    if DESTINATION.exists() and DESTINATION.read_bytes() != data:
        raise SystemExit("Refusing to overwrite a changed authored music asset")
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    DESTINATION.write_bytes(data)
    print(f"PASS: original night motif, {DURATION}s, {SAMPLE_RATE}Hz mono PCM")


if __name__ == "__main__":
    main()
