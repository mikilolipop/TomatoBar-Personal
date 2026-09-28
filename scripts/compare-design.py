"""Create normalized comparison boards from already captured native screenshots."""
from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[1] / 'docs/design-v1.2'
for name in ['day','week','month']:
    source = Image.open(root / f'reference-{name}.png').convert('RGB').resize((1120, 800))
    actual = Image.open(root / 'qa' / f'{name}-native.png').convert('RGB')
    # Exclude the 32pt native title bar, including OS screen-sharing decorations.
    actual = actual.crop((0, 64, actual.width, actual.height)).resize((1120, 800))
    actual.save(root / 'qa' / f'{name}-content.png')
    board = Image.new('RGB',(2240,830),'#f7f0e2')
    board.paste(source,(0,30)); board.paste(actual,(1120,30))
    draw=ImageDraw.Draw(board)
    draw.text((12,8),'SELECTED REFERENCE',fill='#4a3326')
    draw.text((1132,8),'NATIVE APP / ISOLATED FIXTURE',fill='#4a3326')
    board.save(root / 'qa' / f'comparison-final-{name}.png')
    if name == 'day':
        focus=Image.new('RGB',(1000,370),'#f7f0e2')
        focus.paste(source.crop((80,190,500,530)).resize((500,370)),(0,0))
        focus.paste(actual.crop((20,160,400,470)).resize((500,370)),(500,0))
        focus.save(root/'qa'/'comparison-type-color.png')
