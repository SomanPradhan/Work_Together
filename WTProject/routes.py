from flask import Flask, render_template, flash, redirect, url_for, request, abort
from WTProject import app, bcrypt
from WTProject.forms import RegistrationForm, LoginForm, PaswordChangeForm, MeetingForm
from WTProject.query import User
from flask_login import login_user, current_user, logout_user, login_required


@app.route("/")
@app.route("/home")
@login_required
def home():
    posts = User.post_function(current_user.user['username'])
    return render_template('home.html',posts = posts)

@app.route("/register", methods=['get', 'post'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('home'))
    form = RegistrationForm()
    if form.validate_on_submit():
        hashed_password = bcrypt.generate_password_hash(form.password.data).decode('utf-8')
        User.insert_user(form.username.data, form.firstname.data, form.lastname.data, form.email.data, hashed_password)
        flash(f'Account created for { form.username.data }!', 'success')
        return redirect(url_for('login'))
    return render_template('register.html', title = 'Register', form = form)

@app.route("/login", methods=['get', 'post'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('home'))
    form = LoginForm()
    if form.validate_on_submit():
        user = User(form.username.data,form.password.data )
        data = user.login_user(form.username.data)
        if bcrypt.check_password_hash(data,form.password.data):
            login_user(user, remember=form.remember.data)
            next_page = request.args.get('next')
            return redirect (next_page) if next_page else redirect(url_for('home'))
        else:
            flash(f'Login Unsuccessful. Please check the username and password','danger')
    return render_template('login.html', title = 'Login', form = form)

@app.route("/logout")
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route("/change_password", methods = ['get', 'post'])
@login_required
def change_password():
    form = PaswordChangeForm()
    if form.validate_on_submit():
        hash_password = bcrypt.generate_password_hash(form.new_password.data).decode('utf-8')
        User.update_password(current_user.user['username'], hash_password)
        return redirect(url_for('home'))
    return render_template('change_password.html', title = 'Change Password', form = form)


@app.route("/meeting/new", methods = ['get', 'post'])
@login_required
def new_meeting():
    form = MeetingForm()
    if form.validate_on_submit():
        User.add_meeting(form.course.data, form.description.data,current_user.user['username'], form.start_date.data, form.end_date.data, form.max_limit.data, form.min_limit.data, form.location.data)
        flash(f'Your meeting has been created.', 'success')
        return redirect(url_for('home'))
    return render_template('create_meeting.html', title = 'New Meeting', form = form, Legend = 'New Meeting')

@app.route("/meeting/<int:meeting_id>")
def meeting(meeting_id):
    meeting = User.get_meeting(meeting_id, current_user.user['username'])
    val = User.get_student(meeting_id)
    usertype = User.usertyp_return(current_user.user['username'])
    studentid = []
    for student in val:
        studentid.append(student['studentid'])
    return render_template('meeting.html', title=meeting['course'], post=meeting, data = val, usertype = usertype, students = studentid)


@app.route("/meeting/<int:meeting_id>/update", methods=['GET', 'POST'])
@login_required
def update_meeting(meeting_id):
    meeting = User.get_meeting(meeting_id, current_user.user['username'])
    usertype = User.usertyp_return(current_user.user['username'])
    if meeting['meetingowner'] != current_user.user['username'] and usertype == False :
        abort(403)
    form = MeetingForm()
    if form.validate_on_submit():
        meeting['course'] = form.course.data
        meeting['description'] = form.description.data
        meeting['start_date'] = form.start_date.data
        meeting['end_date'] = form.end_date.data
        meeting['max_limit'] = form.max_limit.data
        meeting['min_limit'] = form.min_limit.data
        meeting['location'] = form.location.data
        User.update_meeting(meeting_id, meeting['course'],meeting['description'],meeting['start_date'],meeting['end_date'],meeting['max_limit'],meeting['min_limit'], meeting['location'])
        flash('Your meeting has been updated!', 'success')
        return redirect(url_for('meeting', meeting_id=meeting['id']))
    elif request.method == 'GET':
        form.course.data = meeting['course'] 
        form.description.data = meeting['description']
        form.start_date.data = meeting['start_date']
        form.end_date.data = meeting['end_date'] 
        form.max_limit.data = meeting['max_limit']
        form.min_limit.data = meeting['min_limit'] 
        form.location.data = meeting['location'] 
    return render_template('create_meeting.html', title='Update Meeting',
                           form=form, legend='Update Meeting')


@app.route("/meeting/<int:meeting_id>/delete", methods=['POST'])
@login_required
def delete_meeting(meeting_id):
    usertype = User.usertyp_return(current_user.user['username'])
    if usertype == False:
        abort(403)
    User.delete_meeting(meeting_id)
    flash('Your Meeting has been deleted!', 'success')
    return redirect(url_for('home'))

@app.route("/meeting/<int:meeting_id>/status", methods=['GET', 'POST'])
@login_required
def status_meeting(meeting_id):
    meeting = User.get_meeting(meeting_id, current_user.user['username'])
    val = User.get_student(meeting_id)
    usertype = User.usertyp_return(current_user.user['username'])
    if usertype == False:
        abort(403)
    User.toggle_meeting(meeting_id)
    meeting = User.get_meeting(meeting_id, current_user.user['username'])
    val = User.get_student(meeting_id)
    studentid = []
    for student in val:
        studentid.append(student['studentid'])
    flash('Your Meeting has been changed!', 'success')
    return render_template('meeting.html', title = 'meeting', post=meeting, data = val, usertype = usertype, students = studentid)

@app.route("/meeting/<int:meeting_id>/enroll", methods=['GET', 'POST'])
@login_required
def enroll_meeting(meeting_id):
    meeting = User.get_meeting(meeting_id, current_user.user['username'])
    val = User.get_student(meeting_id)
    usertype = User.usertyp_return(current_user.user['username'])
    if usertype == True:
        abort(403)

    studentid = []
    for student in val:
        studentid.append(student['studentid']) 
    if current_user.user['username'] in studentid and meeting['studentnumber'] == 1:
        User.enroll_meeting(meeting_id, current_user.user['username'], 'delete')
    else:
        User.enroll_meeting(meeting_id, current_user.user['username'], 'update')
    flash('Your Meeting has been changed!', 'success')
    meeting = User.get_meeting(meeting_id, current_user.user['username'])
    val = User.get_student(meeting_id)
    studentid = []
    for student in val:
        studentid.append(student['studentid']) 
    if meeting == False:
        return redirect(url_for('home'))
    return render_template('meeting.html', title = 'meeting', post=meeting, data = val, usertype = usertype, students = studentid)

