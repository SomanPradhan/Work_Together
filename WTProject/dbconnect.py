from psycopg2 import connect, DatabaseError
from psycopg2.extras import RealDictCursor

def connectToDB():
    try:
        return connect(user="postgres",
                                     password="P1@radhan",
                                     host="127.0.0.1",
                                     port="5432",
                                     database="WorkTogetherMeeting",
                                     cursor_factory=RealDictCursor)
    except (Exception, DatabaseError) as error:
        print("Error while connecting to PostgreSQL", error)
        return error

def closeConnection(ps_connection):
    # closing database connection.
    if ps_connection:
        ps_connection.commit()
        ps_connection.close()
        print("PostgreSQL connection is closed")


