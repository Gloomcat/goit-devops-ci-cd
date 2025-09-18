from django.shortcuts import render
from django.db import connection


def index(request):
    """Render a simple index page showing DB connectivity status."""
    db_ok = False
    db_error = None
    try:
        # Works for both SQLite and Postgres
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        db_ok = True
    except Exception as e:  # pragma: no cover
        db_error = str(e)

    return render(request, "index.html", {"db_ok": db_ok, "db_error": db_error})

