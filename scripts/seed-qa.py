"""Seed only the isolated QA12 sandbox. Quit that app before running this script."""
from pathlib import Path
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
import json
import uuid

zone = ZoneInfo('Asia/Shanghai')
def stamp(value):
    return value.timestamp() - 978307200

tags = ['材料力学', '建模', '英语', '编程', '阅读', '数学', '写作']
durations = [25,25,25,25,25,25,25,25,15,25,15,15,15,25]
indexes = [0,0,0,1,1,2,2,3,3,4,4,5,5,6]
records = []
def add(start, minutes, tag, name):
    end = start + timedelta(minutes=minutes)
    records.append(dict(id=str(uuid.uuid4()), name=name, startedAt=stamp(start), endedAt=stamp(end), plannedSeconds=minutes*60, completed=True, segments=[dict(start=stamp(start), end=stamp(end))], tags=[tag]))
    return end
cursor = datetime(2026,9,28,9,tzinfo=zone)
for i, minutes in enumerate(durations):
    cursor = add(cursor, minutes, tags[indexes[i]], tags[indexes[i]]+('练习' if i%2 == 0 else '复习')) + timedelta(minutes=5)
for i, minutes in enumerate([180,120,240,150,210,90,180]):
    cursor = datetime(2026,9,21+i,9,tzinfo=zone)
    for j in range(3):
        cursor = add(cursor, minutes/3, tags[(i+j)%7], '示例专注')
state = dict(phase='idle',paused=False,name='',remaining=0,planned=0,segments=[],rounds=0,records=records,checkpoint=stamp(datetime.now(zone)))
path=Path.home()/'Library/Containers/com.dilyar.TomatoBarPersonal.QA12/Data/Library/Application Support/TomatoBarPersonal/sessions.json'
path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(json.dumps(state,ensure_ascii=False,indent=2))
print(f'Wrote {len(records)} fixture records to QA12 only')
