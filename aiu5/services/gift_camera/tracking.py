"""Track consecutive same-class boxes so momentary detections cannot become gift candidates."""
import uuid

CLASS_NAMES = ["cup", "knife", "bowl", "bed", "book", "scissors", "bird", "dog", "apple", "carrot", "sword", "axe", "pickaxe", "bow", "armor", "helmet", "leggings", "boots"]

def iou(a, b):
    intersection = max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))
    union = (a[2]-a[0])*(a[3]-a[1]) + (b[2]-b[0])*(b[3]-b[1]) - intersection
    return intersection / union if union > 0 else 0

class StableTracker:
    def __init__(self):
        self.previous = []

    def update(self, detections, now):
        unused = self.previous.copy()
        current = []
        for detection in detections[:12]:
            matches = [t for t in unused if t["class_id"] == detection["class_id"] and iou(t["box"], detection["box"]) >= .35 and now-t["last"] < 1.2]
            track = max(matches, key=lambda t: iou(t["box"], detection["box"])) if matches else None
            if track:
                unused.remove(track)
            record = dict(detection, id=track["id"] if track else uuid.uuid4().hex,
                          first=track["first"] if track else now, last=now,
                          hits=track["hits"]+1 if track else 1)
            record["stable"] = record["hits"] >= 3 and now-record["first"] >= .6
            current.append(record)
        self.previous = current
        return [{k:v for k,v in t.items() if k not in ("first", "last", "hits")} for t in current]
