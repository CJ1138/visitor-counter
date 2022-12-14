from flask import Flask
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

from google.cloud import datastore

datastore_client = datastore.Client()

def get_visits():
    query = datastore_client.query(kind='analytics')
    result = list(query.fetch())

    return result[0]['count'] + 1

def set_visits(visits):
    entity = datastore.Entity(key=datastore_client.key('analytics', 'visitors'))
    entity.update({
        'count': visits
    })

    datastore_client.put(entity)

@app.route('/visits', methods=['POST'])
def counter():

    visits = get_visits()

    set_visits(visits)

    return format(visits)

if __name__ == '__main__':
    # This is used when running locally only. When deploying to Google App
    # Engine, a webserver process such as Gunicorn will serve the app. This
    # can be configured by adding an `entrypoint` to app.yaml.
    # Flask's development server will automatically serve static files in
    # the "static" directory. See:
    # http://flask.pocoo.org/docs/1.0/quickstart/#static-files. Once deployed,
    # App Engine itself will serve those files as configured in app.yaml.
    app.run(host='127.0.0.1', port=8080, debug=True)