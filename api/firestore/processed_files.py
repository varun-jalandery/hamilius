import os

from google.cloud import firestore
from google.cloud.firestore import FieldFilter, And


FIRESTORE_CLIENT = None
DATABASE_NAME='hamilius-354828033903e2e6-one'
PROJECT_ID='hamilius'
COLLECTION_NAME = 'processed_files'
def get_firestore_client():
    global FIRESTORE_CLIENT
    if FIRESTORE_CLIENT is None:
        FIRESTORE_CLIENT = firestore.Client(
            database=DATABASE_NAME,
            project=PROJECT_ID
        )
    return FIRESTORE_CLIENT

def query_processed_files(
        status: str,
        content_type: str,
        order_by: str = "created_at_desc",
        limit: int = 10,
):
    db = get_firestore_client()
    processed_files_ref = db.collection(COLLECTION_NAME)

    filters = []
    if status is not None:
        filters.append(FieldFilter('status', '==', status))

    if content_type is not None:
        filters.append(FieldFilter('content_type', '==', content_type))

    if order_by == 'created_at_asc':
        order_by_direction = firestore.Query.ASCENDING
    else:
        order_by_direction = firestore.Query.DESCENDING

    processed_files = (
        processed_files_ref
        .where(filter=And(filters))
        .order_by('created_at', direction=order_by_direction)
        .limit(limit)
        .stream()
    )

    docs = []

    for processed_file in processed_files:
        processed_file_doc = processed_file.to_dict()
        processed_file_doc['id'] = processed_file.id
        docs.append(processed_file_doc)
        print(processed_file_doc['created_at'])

    result = {
        'docs': docs,
        'num_docs': len(docs),
        'limit': limit,
    }
    return result

def get_processed_file(id):
    db = get_firestore_client()
    processed_file_ref = db.collection(COLLECTION_NAME).document(id)
    processed_file_doc = processed_file_ref.get()
    if processed_file_doc.exists:
        processed_file_doc_dict = processed_file_doc.to_dict()
        processed_file_doc_dict['id'] = processed_file_doc.id
        return processed_file_doc_dict
    else:
        return None