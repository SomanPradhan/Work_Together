import re

from flask.globals import current_app
from WTProject.dbconnect import connectToDB, closeConnection
from WTProject import login_manager
from flask_login import UserMixin

@login_manager.user_loader
def load_user(username):
    value = User.get_id(username)
    user = User(value['username'], value['password'])
    return user

class User(UserMixin):
    user = {}

    def __init__(self, username, password):
        self.user['username']  = username 
        self.user['password'] = password


    def post_function(username):
        ps_connection = connectToDB()
        posts = []
        cursor = ps_connection.cursor()
        cursor.execute(f"SELECT * FROM getmeeting('{username}')")
        result = cursor.fetchall()
        for row in result:
            post = {
                'id' : row['id'],
                'topic' : row['course'],
                'description' : row['description'],
                'location' : row['location'],
                'start_date' : row['startdate'],
                'end_date' : row['enddate'],
                'meeting_owner' : '-' if row['meetingowner'] is None else row['meetingowner']
            }
            print(post)
            print(username)
            posts.append(post)
        cursor.close()
        closeConnection(ps_connection)
        return posts

    def insert_user(username, firstname, lastname, email, password):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"call proc_add_user('{username}', '{firstname}', '{lastname}', '{email}', '{password}','false')")
        cursor.close()
        closeConnection(ps_connection)


    def login_user(self,username):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"select * from getuser('{username}')")
        result = cursor.fetchone()
        cursor.close()
        closeConnection(ps_connection)
        return result['password']

    def usertyp_return(username):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"select * from getuser('{username}')")
        result = cursor.fetchone()
        cursor.close()
        closeConnection(ps_connection)
        return result['usertype']

    
    def get_student(meeting_id):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f'select * from getstudent({meeting_id})')
        result = cursor.fetchall()
        datas = []
        for row in result:
            data = {
            'id' : row['meetingid'],
            'studentid' : row['studentid'],
            'enrolleddate' : row['joineddate'],
            'firstname' : row['firstname'],
            'lastname' : row['lastname'],
            'email' : row['email']
            }
            datas.append(data)
        cursor.close()
        closeConnection(ps_connection)
        if result is None:
            return
        return datas

    def toggle_meeting(meeting_id):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"call proc_toggle_meeting({ meeting_id})")
        cursor.close()
        closeConnection(ps_connection)

    def enroll_meeting(meeting_id,username,val):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"call proc_action_meeting_enrolled({meeting_id},'{username}','{val}')")
        cursor.close()
        closeConnection(ps_connection)



    def get_id(username):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        if isinstance(username, dict):
            cursor.execute(f"select * from getuser('{username['username']}')")
        else:
            cursor.execute(f"select * from getuser('{username.user['username']}')")
        result = cursor.fetchall()
        var1 = ''
        var2 = ''
        for row in result:
            var1 = row['username']
            var2 = row['password']
        cursor.close()
        closeConnection(ps_connection)
        return {'username': var1, 'password' : var2}

    
    def update_password(username, password):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"call proc_change_password('{username}', '{password}')")
        cursor.close()
        closeConnection(ps_connection)

    def get_meeting(id, username):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"select * from getmeeting('{username}') where id = {id}")
        result = cursor.fetchone()
        cursor.close()
        closeConnection(ps_connection)
        if result is None:
            return False
        return {'id' : result['id'], 'course' : result['course'], 'description' : result['description'],'start_date': result['startdate'], 'end_date': result['enddate'],'max_limit':result['maxlimit'],'min_limit':result['minlimit'], 'meetingowner': result['meetingowner'], 'location': result['location'], 'status': result['status'], 'studentnumber' : result['studentnumber'], 'usertype': result['utype']}

    def add_meeting(course, description, username,startdate, enddate, maxlimit, minlimit, location):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"call proc_addmeeting('{course}', '{description}','{username}','{startdate}', '{enddate}', '{maxlimit}', '{minlimit}', '{location}')")
        cursor.close()
        closeConnection(ps_connection)

    def update_meeting(id, course, description,startdate, enddate, maxlimit, minlimit, location):
        ps_connection = connectToDB()
        cursor = ps_connection.cursor()
        cursor.execute(f"call proc_update_meeting({id},'{course}', '{description}','{startdate}', '{enddate}', {int(maxlimit)}, {int(minlimit)}, '{location}')")
        cursor.close()
        closeConnection(ps_connection)

    def delete_meeting(id):
        ps_connecton = connectToDB()
        cursor = ps_connecton.cursor()
        cursor.execute(f'call proc_delete_meeting({id})')
        cursor.close()
        closeConnection(ps_connecton)

def taken_username(username):
    ps_connection = connectToDB()
    cursor = ps_connection.cursor()
    cursor.execute(f"select * from getuser('{username}')")
    result = cursor.fetchone()
    cursor.close()
    closeConnection(ps_connection)
    if result:
        return True
    else:
        return False
    

def taken_email(email):
    ps_connection = connectToDB()
    cursor = ps_connection.cursor()
    cursor.execute(f"select * from getemail('{email}')")
    result = cursor.fetchone()
    cursor.close()
    closeConnection(ps_connection)
    if result:
        return True
    else:
        return False

def check_old_password(username):
    ps_connection = connectToDB()
    cursor = ps_connection.cursor()
    cursor.execute(f"select * from getuser('{username}')")
    result = cursor.fetchone()
    cursor.close()
    closeConnection(ps_connection)
    return result['password']
