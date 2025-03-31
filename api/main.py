import datetime
import uuid

import config
import json
import time

from flask import Flask, jsonify, Response, g, request
from firestore.processed_files import query_processed_files, get_processed_file


def create_app():
    app = Flask(__name__)

    # Error 404 handler
    @app.errorhandler(404)
    def resource_not_found(e):
        return jsonify(error=str(e)), 404

    # Error 405 handler
    @app.errorhandler(405)
    def resource_not_found(e):
        return jsonify(error=str(e)), 405

    # Error 401 handler
    @app.errorhandler(401)
    def custom_401(error):
        return Response("API Key required.", 401)

    @app.route("/processed_files", methods=["GET"], strict_slashes=False)
    def processed_files():
        status = request.args.get('status')
        content_type = request.args.get('content_type')
        limit = int(request.args.get('limit', 10))
        order_by = request.args.get('order_by', 'created_at_desc')

        records = query_processed_files(
            status=status,
            content_type=content_type,
            limit=limit,
            order_by=order_by,
        )
        response_body = {
            "success": 1,
            "response": records,
            "status": status,
            "content_type": content_type,
            "limit": limit,
        }
        return jsonify(response_body)

    @app.route("/processed_file/<id>", methods=["GET"], strict_slashes=False)
    def processed_file(id):
        processed_file_doc =  get_processed_file(id)
        if processed_file_doc is not None:
            response_body = {
                "success": 1,
                "response": processed_file_doc,
            }
            return jsonify(response_body)
        else:
            response_body = {
                "success": 0,
                "error": "Processed file not found",
            }
            return jsonify(response_body), 404
    @app.route("/ping")
    def hello_world():
        response_body = {
            "success": 1,
            "ping": "pong",
            "hello": "world",
        }
        return jsonify(response_body)

    @app.route("/version", methods=["GET"], strict_slashes=False)
    def version():
        response_body = {
            "success": 1,
        }
        return jsonify(response_body)

    @app.before_request
    def before_request_func():
        execution_id = uuid.uuid4()
        g.start_time = time.time()
        g.execution_id = execution_id
        print(
            datetime.datetime.now(),
            " ",
            g.execution_id,
            request.method,
            " : ",
            request.url,
            "\n Headers:\n",
            request.headers,
            "\n Data:\n",
            request.data,
            "\n----------------------------\n\n")

    @app.after_request
    def after_request(response):
        if response and response.get_json():
            data = response.get_json()
            data["time_request"] = int(time.time())
            data["version"] = config.VERSION
            response.set_data(json.dumps(data))
        return response
    return app
app = create_app()

if __name__ == "__main__":
    print(" Starting app...")
    app.run(host="0.0.0.0", port=3000)
