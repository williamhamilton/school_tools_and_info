"""
Google Workspace Student Account Creation Script

Purpose:
    - Read student data from a CSV file.
    - Create Google Workspace accounts for students.
    - Set passwords from the CSV.
    - Assign students to a specific OU.
    - Force password reset at first login.
Requirements:
    - Google Service Account with Admin SDK enabled and domain-wide delegation.
    - CSV with columns: First Name, Last Name, Email, Password
    - Install dependencies: pandas, google-api-python-client, google-auth
"""
# ---------------------------------------------------------------------------------------------------------------------
__author__ = "William Hamilton"
__python__ = ""
__created__ = "18/02/2026"
__copyright__ = "Copyright © 2026~"
__license__ = ""
__ToDo__ = """

"""
import pandas as pd
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import csv
import random
import string
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import yaml
import time

# ------------------------
# HELPER FUNCTIONS
# ------------------------
def load_config(config_file="../config.yaml"):
    with open(config_file, "r") as f:
        return yaml.safe_load(f)

def generate_random_password(length=10):
    chars = string.ascii_letters + string.digits + "!@#$%^&*()"
    return ''.join(random.choice(chars) for _ in range(length))

def create_google_service(service_account_file, delegated_admin, scopes):
    credentials = service_account.Credentials.from_service_account_file(
        service_account_file, scopes=scopes
    )
    delegated_credentials = credentials.with_subject(delegated_admin)
    return build('admin', 'directory_v1', credentials=delegated_credentials)

def send_batch_email_html(config_smtp, student_credentials):
    if not student_credentials:
        print("No students to email.")
        return

    msg = MIMEMultipart()
    msg['From'] = config_smtp['user']
    msg['To'] = config_smtp['recipient']
    msg['Cc'] = ", ".join(config_smtp.get('cc', []))
    msg['Subject'] = f"New Student Accounts Created ({len(student_credentials)})"

    # Group by class
    grouped = {}
    for s in student_credentials:
        class_name = s.get('Class', 'No Class')
        grouped.setdefault(class_name, []).append(s)

    # Build HTML table
    html = "<html><body>"
    html += "<p>Hello,</p><p>The following student accounts have been created:</p>"

    for class_name, students in grouped.items():
        html += f"<h3>Class: {class_name}</h3>"
        html += "<table border='1' cellpadding='5' cellspacing='0'><tr><th>First Name</th><th>Last Name</th><th>Email</th><th>Password</th></tr>"
        for stu in students:
            html += f"<tr><td>{stu['First Name']}</td><td>{stu['Last Name']}</td><td>{stu['Email']}</td><td>{stu['Password']}</td></tr>"
        html += "</table><br>"

    html += "<p>Please ensure students change their passwords at first login.</p>"
    html += "<p>Regards,<br>IT Admin</p></body></html>"

    msg.attach(MIMEText(html, 'html'))

    recipients = [config_smtp['recipient']] + config_smtp.get('cc', [])
    with smtplib.SMTP(config_smtp['server'], config_smtp['port']) as server:
        server.starttls()
        server.login(config_smtp['user'], config_smtp['password'])
        server.sendmail(config_smtp['user'], recipients, msg.as_string())
    print(f"✉ Batch HTML email sent to {config_smtp['recipient']}")

# ------------------------
# MAIN SCRIPT
# ------------------------
def main():
    config = load_config()

    # Load CSV
    try:
        df = pd.read_csv(config['script']['csv_file'])
    except FileNotFoundError:
        print(f"CSV not found: {config['script']['csv_file']}")
        return

    # Logs
    with open(config['script']['success_log'], 'w', newline='') as f:
        csv.writer(f).writerow(['First Name', 'Last Name', 'Email', 'Password Used', 'Class'])
    with open(config['script']['failure_log'], 'w', newline='') as f:
        csv.writer(f).writerow(['First Name', 'Last Name', 'Email', 'Password Provided', 'Error', 'Class'])

    # Google API
    service = create_google_service(
        config['google']['service_account_file'],
        config['google']['delegated_admin'],
        ['https://www.googleapis.com/auth/admin.directory.user']
    )

    dry_run = config['script'].get('dry_run', False)
    password_length = config['script'].get('password_length', 10)
    created_students = []

    for _, row in df.iterrows():
        first_name = row.get('First Name')
        last_name = row.get('Last Name')
        email = row.get('Email')
        password = row.get('Password')
        class_name = row.get('Class', 'No Class')

        if pd.isna(first_name) or pd.isna(last_name) or pd.isna(email):
            print(f"Skipping incomplete row: {row}")
            continue

        password_used = password if pd.notna(password) and password.strip() != "" else generate_random_password(password_length)

        try:
            # Check for duplicates
            try:
                service.users().get(userKey=email).execute()
                print(f"⚠ User already exists: {email}")
                continue
            except HttpError as e:
                if e.resp.status != 404:
                    raise

            if not dry_run:
                user_body = {
                    "name": {"givenName": first_name, "familyName": last_name},
                    "password": password_used,
                    "primaryEmail": email,
                    "orgUnitPath": config['google']['org_unit_path'],
                    "changePasswordAtNextLogin": True
                }
                service.users().insert(body=user_body).execute()
                print(f"✅ Created {email}")

            with open(config['script']['success_log'], 'a', newline='') as f:
                csv.writer(f).writerow([first_name, last_name, email, password_used, class_name])

            created_students.append({
                'First Name': first_name,
                'Last Name': last_name,
                'Email': email,
                'Password': password_used,
                'Class': class_name
            })

            # Optional delay for rate limiting
            time.sleep(0.2)

        except Exception as e:
            print(f"❌ Failed {email}: {e}")
            with open(config['script']['failure_log'], 'a', newline='') as f:
                csv.writer(f).writerow([first_name, last_name, email, password, str(e), class_name])

    # Send batch HTML email
    if created_students:
        send_batch_email_html(config['smtp'], created_students)
    else:
        print("No new accounts created. No email sent.")

if __name__ == "__main__":
    main()



