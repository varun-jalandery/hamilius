import os

from cloudevents.http import CloudEvent
from google.cloud import storage, firestore

import functions_framework

PROJECT_ID = os.environ['FIRESTORE_PROJECT_ID']
DATABASE_NAME = os.environ['FIRESTORE_DATABASE_NAME']
COLLECTION_NAME = os.environ['FIRESTORE_COLLECTION_NAME']

@functions_framework.cloud_event
def process_customer_file(cloud_event: CloudEvent) -> tuple:
    data = cloud_event.data
    event_id = cloud_event["id"]
    event_type = cloud_event["type"]
    bucket = data["bucket"]
    name = data["name"]
    metageneration = data["metageneration"]
    time_created = data["timeCreated"]
    updated = data["updated"]
    content_type = data["contentType"]

    print(f"Event ID: {event_id}")
    print(f"Event type: {event_type}")
    print(f"Bucket: {bucket}")
    print(f"File: {name}")
    print(f"Metageneration: {metageneration}")
    print(f"Created: {time_created}")
    print(f"Updated: {updated}")
    print(f"Content type: {content_type}")

    if content_type == "text/plain":
        process_text_file(event_id=event_id, bucket_name=bucket, object_name=name, content_type=content_type)

    else:
        write_doc(
            document_id=event_id,
            object_name=name,
            content_type=content_type,
            status="error",
            error_message="Content type not supported")

    return event_id, event_type, bucket, name, metageneration, time_created, updated

def stream_gcs_object(bucket_name, object_name):
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_name)

    return blob.open("rb")

def write_doc(document_id, object_name, content_type, status, num_lines=None, error_message=None):
    db = firestore.Client(
        database=DATABASE_NAME,
        project=PROJECT_ID
    )
    collection = db.collection(COLLECTION_NAME)

    document_data = {
        "object_name": object_name,
        "content_type": content_type,
        "status": status,
        "created_at": firestore.SERVER_TIMESTAMP,
    }

    if num_lines is not None:
        document_data["num_lines"] = num_lines

    if error_message is not None:
        document_data["error_message"] = error_message
    collection.add(document_data=document_data, document_id=document_id)

def process_text_file(event_id, bucket_name, object_name, content_type):
    try:
        with stream_gcs_object(bucket_name=bucket_name, object_name=object_name) as file_stream:
            line_count = 0
            for line in file_stream:
                decoded_line = line.decode("utf-8")
                line_count += 1
                print(f"Line {line_count}: {decoded_line.strip()}")

            print(f"Processed {line_count} lines from the object.")
            write_doc(
                document_id=event_id,
                object_name=object_name,
                content_type=content_type,
                num_lines=line_count,
                status="processed")
    except Exception as e:
            print(f"Error streaming object: {e}", 500)

