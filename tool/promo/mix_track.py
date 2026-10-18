"""Hazır (telifsiz) bir müzik parçasını tanıtım videosuyla birleştirir ve son
saniyelerde künye yazısı gösterir.

    python tool/promo/mix_track.py <görüntü.mp4> <müzik> <çıktı.mp4> "<künye>" [başlangıç_sn]

Müzik [başlangıç_sn]'den itibaren videonun süresi kadar kesilir, başta kısa
açılır, sonda 2,5 sn'de kısılır.
"""
import re
import subprocess
import sys

import imageio_ffmpeg
from PIL import Image

sys.path.insert(0, __import__('os').path.dirname(__file__))
import make_promo as mp  # noqa: E402

FF = imageio_ffmpeg.get_ffmpeg_exe()


def duration(path):
    out = subprocess.run([FF, '-hide_banner', '-i', path], capture_output=True, text=True).stderr
    h, m, s = re.search(r'Duration: (\d+):(\d+):([\d.]+)', out).groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


def credit_png(text, path):
    im = mp.faded(mp.render_text(text, mp.font(700, 30)), 0.8)
    canvas = Image.new('RGBA', (mp.W, mp.H), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((mp.W - im.size[0]) // 2, mp.H - 90))
    canvas.save(path)


def main(video, music, out, credit, start=0.2):
    dur = duration(video)
    png = out + '.credit.png'
    credit_png(credit, png)
    cs = dur - 4.6
    filt = (f'[0:v][1:v]overlay=0:0:enable=\'gte(t,{cs:.2f})\'[v];'
            f'[2:a]atrim=start={start}:duration={dur:.2f},asetpts=PTS-STARTPTS,volume=0.67,'
            f'afade=t=in:d=0.3,afade=t=out:st={dur - 2.5:.2f}:d=2.5[a]')
    subprocess.run([FF, '-y', '-loglevel', 'error', '-i', video, '-loop', '1', '-i', png, '-i', music,
                    '-filter_complex', filt, '-map', '[v]', '-map', '[a]', '-t', f'{dur:.2f}',
                    '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p',
                    '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', out], check=True)
    print(out, f'{dur:.1f} sn')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], float(sys.argv[5]) if len(sys.argv) > 5 else 0.2)
