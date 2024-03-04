from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, SubmitField, BooleanField, TextAreaField, DecimalField
from wtforms import validators
from wtforms.fields.html5 import DateTimeLocalField
from wtforms.validators import DataRequired, Length, Email, EqualTo, Regexp, ValidationError, NumberRange, Optional
from WTProject.query import taken_username, taken_email, check_old_password
from flask_login import current_user
from WTProject import bcrypt
from datetime import datetime

class RegistrationForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired(), Length(min=2, max=30), Regexp(r'^[\w.@+-]+$')])
    firstname = StringField('First Name', validators=[DataRequired()])
    lastname = StringField('Last Name', validators=[DataRequired()])
    email = StringField('E-mail', validators=[DataRequired(), Email()])
    password = PasswordField('Password', validators=[DataRequired(), Length(min=6, max=30)])
    confirm_password = PasswordField('Confirm Password', validators=[DataRequired(), EqualTo('password')])
    submit = SubmitField('Sign Up')

    def validate_username(self, username):
        if taken_username(username.data):
            raise ValidationError('The username is already taken. Please enter another username')
    

    def validate_email(self, email):
        if taken_email(email.data):
            raise ValidationError('The email is already taken. Please enter another email')


class LoginForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired()])
    password = PasswordField('Password', validators=[DataRequired()])
    remember = BooleanField('Remember me')
    submit = SubmitField('Login')

class PaswordChangeForm(FlaskForm):
    old_password = PasswordField('Old Password', validators=[DataRequired(), Length(min=6, max=30)])
    new_password = PasswordField('New Password', validators=[DataRequired(), Length(min=6, max=30)])
    confirm_password = PasswordField('Confirm Password', validators=[DataRequired(), EqualTo('new_password')])
    submit = SubmitField('Update')

    def validate_oldPassword(self, old_password):
        if not(bcrypt.check_password_hash(check_old_password(current_user.user['username']), old_password.data)):
            raise ValidationError('The username is already taken. Please enter another username')


class MeetingForm(FlaskForm):
    course = StringField('Course', validators=[DataRequired()])
    description = TextAreaField('Description', validators=[DataRequired()])
    start_date = DateTimeLocalField('Start Date', format='%Y-%m-%dT%H:%M', validators = [DataRequired()])
    end_date = DateTimeLocalField('End Date', format='%Y-%m-%dT%H:%M', validators = [DataRequired()])
    max_limit = DecimalField('Max Limit', validators=[Optional(), NumberRange(min = 2)])
    min_limit = DecimalField('Min Limit', validators = [Optional(), NumberRange(min = 2)])
    location = StringField('Location', validators = [DataRequired()])
    submit = SubmitField('Post')

    def validate_start_date(self, start_date):
        if datetime.now() >= start_date.data:
            raise ValidationError('Start date must be greater than Current Date and time')

    def validate_end_date(self, end_date):
        if self.start_date.data >= end_date.data:
            raise ValidationError('End Date must be greater than Start Date')

    def validate_min_limit(self, min_limit):
        if self.max_limit.data < min_limit.data:
            raise ValidationError('Max Limit must be greater or equal to than Min Limit')

