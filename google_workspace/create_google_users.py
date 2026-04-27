"""
Google Workspace Student Account Creation Script

Purpose:
    - Read student data from a CSV file.
    - Create Google Workspace accounts for students.
    - Set passwords from the CSV (or auto-generate if not provided).
    - Assign students to a specific OU.
    - Optionally force password reset at first login (configurable).
Requirements:
    - Google Service Account with Admin SDK enabled and domain-wide delegation.
    - CSV with columns: First Name, Last Name, Email, Password (optional), Class (optional)
    - Install dependencies: pandas, google-api-python-client, google-auth
"""
# ---------------------------------------------------------------------------------------------------------------------
__author__ = "William Hamilton"
__python__ = "3.8+"
__created__ = "18/02/2026"
__updated__ = "22/02/2026"
__copyright__ = "Copyright © 2026~"
__license__ = ""
__ToDo__ = """

"""
import argparse
import csv
import logging
import os
import re
import secrets
import smtplib
import string
import time
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path
from typing import Dict, List

import pandas as pd
import yaml
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from google.oauth2 import service_account

# ---------------------------------------------------------------------
# Logging Configuration
# ---------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = BASE_DIR.parent / "config.yaml"
EMAIL_REGEX = re.compile(r"^[^@]+@[^@]+\.[^@]+$")


# ---------------------------------------------------------------------
# Utility Functions
# ---------------------------------------------------------------------
def generate_secure_password(length: int = 12) -> str:
    chars = string.ascii_letters + string.digits + "!@#$%^&*()"
    return ''.join(secrets.choice(chars) for _ in range(length))


def validate_email(email: str) -> bool:
    return bool(EMAIL_REGEX.match(email))


def load_config(config_file: Path = DEFAULT_CONFIG_PATH) -> dict:
    with open(config_file, "r") as f:
        return yaml.safe_load(f)


def create_google_service(service_account_file: str, delegated_admin: str):
    credentials = service_account.Credentials.from_service_account_file(
        service_account_file,
        scopes=['https://www.googleapis.com/auth/admin.directory.user']
    )
    delegated_credentials = credentials.with_subject(delegated_admin)
    return build('admin', 'directory_v1', credentials=delegated_credentials)


def user_exists(service, email: str) -> bool:
    try:
        service.users().get(userKey=email).execute()
        return True
    except HttpError as e:
        if hasattr(e, "resp") and e.resp.status == 404:
            return False
        raise


def create_user_with_retry(service, user_body: dict, retries: int = 3):
    for attempt in range(retries):
        try:
            service.users().insert(body=user_body).execute()
            return
        except HttpError:
            if attempt == retries - 1:
                raise
            wait_time = 2 ** attempt
            logger.warning(f"Retrying in {wait_time}s...")
            time.sleep(wait_time)


def send_batch_email(config: dict, students: List[Dict], dry_run: bool = False) -> None:
    """
    Send batch HTML email with student account info.
    If dry_run=True, it just logs the intended recipients instead of sending.

    Args:
        config (dict): Config dictionary.
        students (List[Dict]): List of student dicts.
        dry_run (bool): If True, skip actual SMTP sending.
    """
    if not students:
        logger.info("No students to email.")
        return

    smtp_cfg = config["smtp"]
    include_password = config["script"].get("include_password_in_email", True)

    if dry_run:
        recipients = [smtp_cfg["recipient"]] + smtp_cfg.get("cc", [])
        logger.info(f"[Dry Run] Would send email to: {recipients}")
        logger.info(f"[Dry Run] Would include {len(students)} student accounts in email.")
        return

    smtp_password = os.getenv(smtp_cfg.get("password_env", "SMTP_PASSWORD"))
    if not smtp_password:
        logger.error("SMTP password environment variable not set.")
        return

    msg = MIMEMultipart()
    msg["From"] = smtp_cfg["user"]
    msg["To"] = smtp_cfg["recipient"]
    msg["Cc"] = ", ".join(smtp_cfg.get("cc", []))
    msg["Subject"] = f"New Student Accounts Created ({len(students)})"

    grouped = {}
    for student in students:
        grouped.setdefault(student.get("Class", "No Class"), []).append(student)

    html = "<html><body><p>Hello,</p>"
    html += "<p>The following student accounts have been created:</p>"

    for class_name, class_students in grouped.items():
        html += f"<h3>Class: {class_name}</h3>"
        html += "<table border='1' cellpadding='5'>"
        html += "<tr><th>First Name</th><th>Last Name</th><th>Email</th>"
        if include_password:
            html += "<th>Password</th>"
        html += "</tr>"

        for stu in class_students:
            html += f"<tr><td>{stu['First Name']}</td>"
            html += f"<td>{stu['Last Name']}</td>"
            html += f"<td>{stu['Email']}</td>"
            if include_password:
                html += f"<td>{stu['Password']}</td>"
            html += "</tr>"

        html += "</table><br>"

    html += "<p>Students must change passwords at first login.</p>"
    html += "<p>Regards,<br>IT Admin</p></body></html>"

    msg.attach(MIMEText(html, "html"))
    recipients = [smtp_cfg["recipient"]] + smtp_cfg.get("cc", [])

    try:
        with smtplib.SMTP(smtp_cfg["server"], smtp_cfg["port"]) as server:
            server.starttls()
            server.login(smtp_cfg["user"], smtp_password)
            server.sendmail(smtp_cfg["user"], recipients, msg.as_string())
        logger.info("Batch email sent successfully.")
    except smtplib.SMTPException as e:
        logger.error(f"Failed to send email: {e}")


# ---------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------
def parse_args():
    parser = argparse.ArgumentParser(description="Google Workspace Student Account Creator")
    parser.add_argument("--csv")
    parser.add_argument("--ou")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--recipient")
    return parser.parse_args()


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
def main() -> dict:
    """
    Run the student account creation process.

    Returns:
        dict: {"success_count": int, "failure_count": int, "created_students": List[Dict]}
    """
    config = load_config()
    args = parse_args()

    if args.csv:
        config["script"]["csv_file"] = args.csv
    if args.ou:
        config["google"]["org_unit_path"] = args.ou
    if args.recipient:
        config["smtp"]["recipient"] = args.recipient
    if args.dry_run:
        config["script"]["dry_run"] = True

    dry_run = config["script"].get("dry_run", False)
    password_length = config["script"].get("password_length", 12)
    rate_delay = config["script"].get("rate_limit_delay", 0.2)
    force_password_change = config["script"].get("force_password_change_at_login", True)

    try:
        df = pd.read_csv(config["script"]["csv_file"])
    except FileNotFoundError:
        logger.error("CSV file not found.")
        return {"success_count": 0, "failure_count": 0, "created_students": []}

    # Open log files once
    success_file = open(config["script"]["success_log"], "w", newline="")
    failure_file = open(config["script"]["failure_log"], "w", newline="")

    success_writer = csv.writer(success_file)
    failure_writer = csv.writer(failure_file)

    success_writer.writerow(["First Name", "Last Name", "Email", "Class"])
    failure_writer.writerow(["First Name", "Last Name", "Email", "Error", "Class"])

    service = None
    if not dry_run:
        service = create_google_service(
            config["google"]["service_account_file"],
            config["google"]["delegated_admin"]
        )

    created_students = []
    failure_count = 0

    for idx, row in df.iterrows():

        first_name = str(row.get("First Name", "")).strip() if pd.notna(row.get("First Name")) else ""
        last_name = str(row.get("Last Name", "")).strip() if pd.notna(row.get("Last Name")) else ""
        email = str(row.get("Email", "")).strip() if pd.notna(row.get("Email")) else ""
        password = str(row.get("Password", "")).strip() if pd.notna(row.get("Password")) else ""
        class_name = row.get("Class", "No Class")

        if not first_name or not last_name or first_name == "nan" or last_name == "nan":
            logger.warning(f"Row {idx}: Missing name.")
            failure_count += 1
            failure_writer.writerow([first_name, last_name, email, "Missing name", class_name])
            continue

        # Auto-generate email if missing
        if not email and config["google"].get("auto_generate_email"):
            domain = config["google"]["default_domain"]
            clean_first = re.sub(r"[^a-zA-Z0-9]", "", first_name)
            clean_last = re.sub(r"[^a-zA-Z0-9]", "", last_name)
            email = f"{clean_first}.{clean_last}@{domain}".lower()

        if not validate_email(email):
            logger.warning(f"Row {idx}: Invalid email format: {email}")
            failure_count += 1
            failure_writer.writerow([first_name, last_name, email, "Invalid email", class_name])
            continue

        try:
            if not dry_run and user_exists(service, email):
                logger.info(f"User already exists: {email}")
                continue

            # Use password from CSV if provided, otherwise generate one
            if not password:
                password = generate_secure_password(password_length)

            if not dry_run:
                user_body = {
                    "name": {"givenName": first_name, "familyName": last_name},
                    "password": password,
                    "primaryEmail": email,
                    "orgUnitPath": config["google"]["org_unit_path"],
                    "changePasswordAtNextLogin": force_password_change
                }
                create_user_with_retry(service, user_body)
                logger.info(f"Created: {email}")

            success_writer.writerow([first_name, last_name, email, class_name])

            created_students.append({
                "First Name": first_name,
                "Last Name": last_name,
                "Email": email,
                "Password": password,
                "Class": class_name
            })

        except HttpError as e:
            status = getattr(e.resp, "status", "Unknown")
            logger.error(f"API error for {email}: {status}")
            failure_writer.writerow([first_name, last_name, email, status, class_name])
            failure_count += 1

        except Exception as e:
            logger.error(f"Unexpected error for {email}: {str(e)}")
            failure_writer.writerow([first_name, last_name, email, str(e), class_name])
            failure_count += 1

        time.sleep(rate_delay)

    success_file.close()
    failure_file.close()

    if not dry_run:
        send_batch_email(config, created_students, dry_run=False)
    else:
        send_batch_email(config, created_students, dry_run=True)

    logger.info(f"Process complete. Created {len(created_students)} accounts.")
    logger.info(f"Success: {len(created_students)}")
    logger.info(f"Failures: {failure_count}")

    return {
        "success_count": len(created_students),
        "failure_count": failure_count,
        "created_students": created_students
    }


if __name__ == "__main__":
    main()
