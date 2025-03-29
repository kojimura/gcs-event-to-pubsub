import os
import time
import logging
import json

logging.basicConfig(level=logging.INFO)

def get_sleep_duration(msg: str) -> int:
    if "60" in msg:
        return 60 * 60
    elif "10" in msg:
        return 10 * 60
    elif "1" in msg:
        return 60
    else:
        return 0

def main():
    msg = os.environ.get("PUBSUB_MSG", "")
    try:
        logging.info(f"Received PUBSUB_MSG: {msg}")
  
        if msg.startswith("{"):
            parsed = json.loads(msg)
            name = parsed.get("name", "unknown")
        else:
            name = msg
    except Exception as e:
        logging.error(f"Error decoding message: {e}")
        name = "unknown"

    duration = get_sleep_duration(name)
    logging.info(f"[BG] Start processing {name}")
    logging.info(f"[BG] Sleeping for {duration} seconds...")
    time.sleep(duration)
    logging.info(f"[BG] Finished processing {name}")

if __name__ == "__main__":
    main()
