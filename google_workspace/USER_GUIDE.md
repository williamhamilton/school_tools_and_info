# Google Workspace Student Account Creation Script - User Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Preparing Your CSV File](#preparing-your-csv-file)
6. [Running the Script](#running-the-script)
7. [Understanding the Output](#understanding-the-output)
8. [Command-Line Options](#command-line-options)
9. [Dry Run Mode](#dry-run-mode)
10. [Email Notifications](#email-notifications)
11. [Troubleshooting](#troubleshooting)
12. [Best Practices](#best-practices)
13. [FAQ](#faq)

---

## Overview

This script automates the creation of Google Workspace student accounts in bulk. It:

- ✅ Reads student data from a CSV file
- ✅ Creates Google Workspace accounts with secure passwords
- ✅ Assigns students to a specific Organisational Unit (OU)
- ✅ Forces password change at first login
- ✅ Validates email addresses and names
- ✅ Handles errors gracefully with detailed logging
- ✅ Sends email notifications with account details
- ✅ Supports dry-run mode for testing
- ✅ Auto-generates emails if missing (optional)

**Author:** William Hamilton  
**Created:** February 22, 2026  
**Python Version:** 3.8+

---

## Prerequisites

### 1. Google Workspace Requirements

You must have:

- **Google Workspace Admin Access** - Super Admin or User Management Admin role
- **Service Account** with:
  - Admin SDK API enabled
  - Domain-wide delegation configured
  - Proper scopes: `https://www.googleapis.com/auth/admin.directory.user`
- **Service Account JSON Key File** - Downloaded from Google Cloud Console

### 2. System Requirements

- **Python 3.8 or higher**
- **Operating System:** macOS, Linux, or Windows
- **Internet connection** for API calls
- **SMTP server access** for email notifications

### 3. Required Python Packages

Install these dependencies (see [Installation](#installation)):
- `pandas` - CSV processing
- `google-api-python-client` - Google Workspace API
- `google-auth` - Authentication
- `pyyaml` - Configuration file parsing

---

## Installation

### Step 1: Clone or Download the Project

```bash
cd /path/to/your/projects
git clone <repository-url>
cd school_tools_and_info
```

### Step 2: Create a Virtual Environment (Recommended)

```bash
# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate  # macOS/Linux
# or
.venv\Scripts\activate  # Windows
```

### Step 3: Install Dependencies

```bash
pip install -r requirements.txt
```

The `requirements.txt` includes:
```
pandas>=2.0.0
google-api-python-client>=2.100.0
google-auth>=2.23.0
google-auth-httplib2>=0.1.1
google-auth-oauthlib>=1.1.0
PyYAML>=6.0
```

### Step 4: Verify Installation

```bash
python -c "import pandas, yaml, googleapiclient; print('All dependencies installed!')"
```

---

## Configuration

### Step 1: Copy the Example Config

```bash
cp config.yaml.example config.yaml
```

### Step 2: Edit config.yaml

Open `config.yaml` and update the following sections:

#### Google Workspace Settings

```yaml
google:
  service_account_file: "path/to/your/service_account.json"
  delegated_admin: "admin@yourschool.school.nz"
  org_unit_path: "/Students"
  auto_generate_email: true
  default_domain: "yourschool.school.nz"
```

**Parameters:**
- `service_account_file` - Path to your service account JSON key file
- `delegated_admin` - Admin email for domain-wide delegation
- `org_unit_path` - OU where students will be created (e.g., `/Students`, `/Students/Year7`)
- `auto_generate_email` - If `true`, generates emails from names when missing
- `default_domain` - Your school's domain for auto-generated emails

#### Script Settings

```yaml
script:
  csv_file: "students.csv"
  success_log: "created_accounts.csv"
  failure_log: "failed_accounts.csv"
  password_length: 12
  dry_run: false
  rate_limit_delay: 0.2
  include_password_in_email: true
```

**Parameters:**
- `csv_file` - Path to your input CSV file
- `success_log` - Output file for successfully created accounts
- `failure_log` - Output file for failed accounts
- `password_length` - Length of auto-generated passwords (minimum 8, recommended 12+)
- `dry_run` - If `true`, validates data without creating accounts
- `rate_limit_delay` - Seconds to wait between API calls (default 0.2)
- `include_password_in_email` - If `true`, includes passwords in notification email

#### SMTP Settings

```yaml
smtp:
  server: "smtp.office365.com"
  port: 587
  user: "it@yourschool.school.nz"
  password_env: "SMTP_PASSWORD"
  recipient: "teachers@yourschool.school.nz"
  cc:
    - "principal@yourschool.school.nz"
    - "admin@yourschool.school.nz"
```

**Parameters:**
- `server` - SMTP server hostname
- `port` - SMTP port (587 for TLS, 465 for SSL)
- `user` - Email account for sending
- `password_env` - Environment variable name containing the SMTP password
- `recipient` - Primary recipient for notifications
- `cc` - List of CC recipients (optional)

### Step 3: Set SMTP Password Environment Variable

```bash
# For current session
export SMTP_PASSWORD="your_smtp_password"

# Or add to ~/.bashrc or ~/.zshrc for persistence
echo 'export SMTP_PASSWORD="your_smtp_password"' >> ~/.zshrc
```

**Windows:**
```cmd
set SMTP_PASSWORD=your_smtp_password
```

### Step 4: Place Your Service Account File

```bash
# Copy your service account JSON to the project directory
cp ~/Downloads/service-account-key.json ./service_account.json
```

**Security Note:** Never commit this file to version control! It's already in `.gitignore`.

---

## Preparing Your CSV File

### Required Format

Create a CSV file with the following columns:

| Column Name | Required | Description | Example |
|-------------|----------|-------------|---------|
| First Name | ✅ Yes | Student's first name | `Alice` |
| Last Name | ✅ Yes | Student's last name | `Smith` |
| Email | ⚠️ Conditional* | Student's email address | `alice.smith@school.com` |
| Class | ❌ No | Student's class/year group | `Year 7` |

*Email is required UNLESS `auto_generate_email: true` in config

### Example CSV

**students.csv:**
```csv
First Name,Last Name,Email,Class
Alice,Smith,alice.smith@school.com,Year 7
Bob,Jones,bob.jones@school.com,Year 7
Charlie,Brown,charlie.brown@school.com,Year 8
Diana,Prince,diana.prince@school.com,Year 8
```

### Example CSV with Auto-Generated Emails

If `auto_generate_email: true`:

```csv
First Name,Last Name,Email,Class
Alice,Smith,,Year 7
Bob,Jones,,Year 7
Charlie,Brown,charlie.b@school.com,Year 8
Diana,Prince,,Year 8
```

The script will generate:
- `alice.smith@school.com` (auto-generated)
- `bob.jones@school.com` (auto-generated)
- `charlie.b@school.com` (uses provided email)
- `diana.prince@school.com` (auto-generated)

### Data Validation Rules

The script validates:

1. **Names:** Must not be empty or contain only whitespace
2. **Email:** Must match pattern `[something]@[domain].[tld]`
3. **Special characters:** Names are sanitized for email generation (removed)
4. **Duplicates:** Script checks if user already exists before creating

---

## Running the Script

### Basic Usage

```bash
python google_workspace/create_google_users.py
```

This uses all settings from `config.yaml`.

### First Run - Use Dry Run Mode!

**Always test with dry-run first:**

```bash
python google_workspace/create_google_users.py --dry-run
```

This will:
- ✅ Validate your CSV data
- ✅ Check for errors
- ✅ Show what would be created
- ✅ Generate a test email
- ❌ NOT create any actual accounts

### Production Run

After verifying dry-run results:

```bash
python google_workspace/create_google_users.py
```

### Watch the Progress

The script provides real-time logging:

```
2026-02-22 10:30:15 - INFO - Loaded config from config.yaml
2026-02-22 10:30:16 - INFO - Created: alice.smith@school.com
2026-02-22 10:30:16 - INFO - Created: bob.jones@school.com
2026-02-22 10:30:17 - WARNING - Row 3: Invalid email format: notanemail
2026-02-22 10:30:17 - INFO - Created: diana.prince@school.com
2026-02-22 10:30:18 - INFO - Process complete. Created 3 accounts.
2026-02-22 10:30:18 - INFO - Success: 3
2026-02-22 10:30:18 - INFO - Failures: 1
```

---

## Understanding the Output

### Success Log

**File:** `created_accounts.csv` (or as configured)

Contains all successfully created accounts:

```csv
First Name,Last Name,Email,Class
Alice,Smith,alice.smith@school.com,Year 7
Bob,Jones,bob.jones@school.com,Year 7
Diana,Prince,diana.prince@school.com,Year 8
```

**Use this file to:**
- Track which accounts were created
- Verify account details
- Audit the creation process

### Failure Log

**File:** `failed_accounts.csv` (or as configured)

Contains accounts that failed with error reasons:

```csv
First Name,Last Name,Email,Error,Class
,,missing@school.com,Missing name,Year 7
John,,nobrown@school.com,Missing name,Year 8
Jane,Doe,notanemail,Invalid email,Year 9
```

**Common error messages:**
- `Missing name` - First or last name is empty
- `Invalid email` - Email format is incorrect
- `409` - User already exists (HTTP error code)
- `403` - Permission denied (check service account)
- `500` - Google API error (temporary, try again)

### Email Notification

Recipients receive an HTML email with:

**Subject:** `Student Accounts Created - [Date]`

**Content:**
- Summary of accounts created
- Table grouped by class
- Account details (email, password if enabled)
- Links to success/failure logs

**Example:**

```
Student Accounts Created

The following student accounts have been created:

Year 7 (2 students)
┌─────────────┬──────────────┬───────────────────────────┬──────────────┐
│ First Name  │ Last Name    │ Email                     │ Password     │
├─────────────┼──────────────┼───────────────────────────┼──────────────┤
│ Alice       │ Smith        │ alice.smith@school.com    │ xK9pL#mQ2vR  │
│ Bob         │ Jones        │ bob.jones@school.com      │ aB7#qW9nM4pL │
└─────────────┴──────────────┴───────────────────────────┴──────────────┘

Please distribute these credentials securely.
Students will be required to change their password on first login.
```

---

## Command-Line Options

Override config file settings with command-line arguments:

### --csv

Specify a different CSV file:

```bash
python google_workspace/create_google_users.py --csv new_students_2026.csv
```

### --ou

Override the organisational unit:

```bash
python google_workspace/create_google_users.py --ou "/Students/Year7"
```

### --dry-run

Enable dry-run mode (no accounts created):

```bash
python google_workspace/create_google_users.py --dry-run
```

### --recipient

Change the email recipient:

```bash
python google_workspace/create_google_users.py --recipient principal@school.com
```

### Combining Options

```bash
python google_workspace/create_google_users.py \
  --csv year7_students.csv \
  --ou "/Students/Year7" \
  --recipient year7_teacher@school.com \
  --dry-run
```

---

## Dry Run Mode

**ALWAYS use dry-run mode before production runs!**

### What Dry Run Does

✅ **Does:**
- Reads and validates CSV file
- Checks email format
- Validates names
- Generates passwords
- Creates log files
- Sends test email notification

❌ **Doesn't:**
- Create actual Google accounts
- Make any API calls to Google
- Check if users already exist
- Consume API quota

### When to Use Dry Run

1. **First time using the script** - Verify everything works
2. **New CSV file** - Check for data errors
3. **Testing configuration changes** - Ensure settings are correct
4. **Large batches** - Preview what will be created
5. **After long breaks** - Refresh your memory

### How to Enable

**Method 1: Config file**
```yaml
script:
  dry_run: true
```

**Method 2: Command-line**
```bash
python google_workspace/create_google_users.py --dry-run
```

**Note:** Command-line option overrides config file.

---

## Email Notifications

### Email Grouping

Students are automatically grouped by class in the email:

```
Year 7 (2 students)
  - alice.smith@school.com
  - bob.jones@school.com

Year 8 (3 students)
  - charlie.brown@school.com
  - diana.prince@school.com
  - eve.adams@school.com
```

### Password Inclusion

**Security consideration:**

```yaml
script:
  include_password_in_email: true  # Includes passwords in email
  include_password_in_email: false # Omits passwords (more secure)
```

**Recommendation:**
- Use `true` for initial distribution
- Send to trusted recipients only
- Consider encrypting the email or using secure channels

### CC Recipients

Add multiple people to CC:

```yaml
smtp:
  cc:
    - "principal@school.com"
    - "admin@school.com"
    - "it@school.com"
```

### Disabling Email Notifications

To disable (not recommended):

Comment out the email sending lines in the script, or set invalid SMTP settings to skip email sending on error.

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: "CSV file not found"

**Error:** `FileNotFoundError: CSV file not found.`

**Solution:**
- Check the file path in `config.yaml`
- Use absolute path: `/full/path/to/students.csv`
- Or relative path: `./students.csv` (same directory)
- Verify file exists: `ls -la students.csv`

#### Issue: "Service account permission denied"

**Error:** `HttpError 403: Not authorized to access this resource`

**Solution:**
1. Verify domain-wide delegation is configured
2. Check delegated admin email is correct
3. Ensure service account has proper scopes:
   ```
   https://www.googleapis.com/auth/admin.directory.user
   ```
4. Wait 10-15 minutes after configuration changes

#### Issue: "SMTP authentication failed"

**Error:** `SMTPAuthenticationError: Username and Password not accepted`

**Solution:**
- Verify SMTP password environment variable: `echo $SMTP_PASSWORD`
- Check SMTP server and port are correct
- For Office 365, enable SMTP AUTH in admin centre
- For Gmail, use App Password (not regular password)

#### Issue: "User already exists"

**Behavior:** Script logs "User already exists: email@domain.com" and skips

**Solution:**
- This is normal behavior (prevents duplicates)
- To recreate: Delete user in Google Admin Console first
- Or update the CSV to remove duplicate entries

#### Issue: "Invalid email format"

**Error:** `WARNING - Row 5: Invalid email format: notanemail`

**Solution:**
- Check email format: must be `something@domain.com`
- Remove spaces or special characters
- Enable auto-generate if emails are missing:
  ```yaml
  google:
    auto_generate_email: true
  ```

#### Issue: "Missing name"

**Error:** `WARNING - Row 3: Missing name.`

**Solution:**
- Ensure First Name and Last Name columns have values
- Check for empty cells in CSV
- Remove or fill incomplete rows

#### Issue: "Rate limit exceeded"

**Error:** `HttpError 429: Rate limit exceeded`

**Solution:**
- Increase `rate_limit_delay` in config:
  ```yaml
  script:
    rate_limit_delay: 0.5  # Increase from 0.2 to 0.5
  ```
- Run in smaller batches
- Wait and retry after a few minutes

### Debugging Tips

#### Enable Verbose Logging

Edit the script to set logging level to DEBUG:

```python
logging.basicConfig(
    level=logging.DEBUG,  # Changed from INFO
    format="%(asctime)s - %(levelname)s - %(message)s"
)
```

#### Check Service Account Permissions

```bash
# Verify service account file exists
ls -la service_account.json

# Check JSON is valid
python -c "import json; print(json.load(open('service_account.json'))['client_email'])"
```

#### Test Google API Connection

Create a test script:

```python
from google.oauth2 import service_account
from googleapiclient.discovery import build

credentials = service_account.Credentials.from_service_account_file(
    'service_account.json',
    scopes=['https://www.googleapis.com/auth/admin.directory.user']
)
delegated = credentials.with_subject('admin@yourschool.school.nz')
service = build('admin', 'directory_v1', credentials=delegated)

# Try to list users
result = service.users().list(domain='yourschool.school.nz', maxResults=1).execute()
print("Connection successful!", result)
```

---

## Best Practices

### 1. Security

- ✅ **Never commit** `config.yaml` or `service_account.json` to version control
- ✅ **Use environment variables** for sensitive data (SMTP password)
- ✅ **Restrict service account** to minimum required scopes
- ✅ **Use strong passwords** (minimum 12 characters)
- ✅ **Rotate service account keys** regularly (annually)
- ✅ **Encrypt email notifications** if sending passwords
- ✅ **Delete password records** after distribution

### 2. Testing

- ✅ **Always dry-run first** before production
- ✅ **Test with small batch** (5-10 students) initially
- ✅ **Verify in Google Admin** that accounts are correct
- ✅ **Test login** with a sample account
- ✅ **Review logs** for any warnings or errors

### 3. Data Management

- ✅ **Keep CSV files organized** by date or cohort
- ✅ **Backup CSV files** before processing
- ✅ **Archive success/failure logs** for audit trail
- ✅ **Clean CSV data** before processing (remove duplicates, fix formatting)
- ✅ **Use consistent naming** conventions for files

### 4. Operations

- ✅ **Run during low-usage hours** to avoid rate limits
- ✅ **Process in batches** for large numbers (50-100 at a time)
- ✅ **Monitor logs** during execution
- ✅ **Verify accounts** in Google Admin Console after creation
- ✅ **Document your process** for team members

### 5. Account Management

- ✅ **Use consistent OU structure** (e.g., `/Students/Year7`, `/Students/Year8`)
- ✅ **Force password change** at first login (script does this automatically)
- ✅ **Set account recovery options** in Google Admin
- ✅ **Apply group policies** after creation
- ✅ **Enable 2FA** for security

---

## FAQ

### Q: Can I create accounts for staff or teachers?

**A:** Yes! Just adjust the `org_unit_path` in config or use `--ou` flag:
```bash
python google_workspace/create_google_users.py --csv staff.csv --ou "/Staff"
```

### Q: What happens if the script crashes midway?

**A:** The script processes users sequentially and logs each success/failure. Check:
- `created_accounts.csv` - Shows which accounts were created
- `failed_accounts.csv` - Shows which failed
- Simply run again with remaining users (script skips existing accounts)

### Q: Can I use custom passwords from CSV?

**A:** Not in current version. The script generates secure random passwords automatically. This is more secure than using predictable passwords.

### Q: How do I create accounts in multiple OUs?

**A:** Run the script multiple times with different CSV files and OU settings:
```bash
python google_workspace/create_google_users.py --csv year7.csv --ou "/Students/Year7"
python google_workspace/create_google_users.py --csv year8.csv --ou "/Students/Year8"
```

### Q: Can I set custom user properties (phone, address, etc.)?

**A:** Not in current version. The script creates basic accounts. Use Google Admin Console or another script to add additional properties after creation.

### Q: How many accounts can I create at once?

**A:** Technically unlimited, but:
- **Recommended:** 50-100 per batch
- **Rate limits:** Google has API quotas
- **Best practice:** Test with 5-10 first, then scale up

### Q: What if I need to delete accounts?

**A:** Use Google Admin Console or create a separate deletion script. This script only creates accounts.

### Q: Can I schedule this to run automatically?

**A:** Yes! Use cron (Linux/Mac) or Task Scheduler (Windows):

**Cron example (daily at 2 AM):**
```bash
0 2 * * * cd /path/to/project && source .venv/bin/activate && python google_workspace/create_google_users.py
```

### Q: How do I update the script?

**A:** Pull the latest version from the repository:
```bash
git pull origin main
pip install -r requirements.txt  # Update dependencies if changed
```

### Q: Where can I get support?

**A:** 
- Check this user guide first
- Review the [Troubleshooting](#troubleshooting) section
- Check GitHub issues or contact the script maintainer
- Review Google Workspace Admin SDK documentation

---

## Quick Reference Card

### Pre-Flight Checklist

- [ ] Service account JSON file in place
- [ ] `config.yaml` configured with correct settings
- [ ] SMTP password environment variable set
- [ ] CSV file prepared with correct format
- [ ] Tested with dry-run mode
- [ ] Small test batch successful

### Command Quick Reference

```bash
# Dry run (test mode)
python google_workspace/create_google_users.py --dry-run

# Production run
python google_workspace/create_google_users.py

# Custom CSV and OU
python google_workspace/create_google_users.py --csv new_students.csv --ou "/Students/Year7"

# Change recipient
python google_workspace/create_google_users.py --recipient teacher@school.com

# Check logs
tail -f created_accounts.csv
tail -f failed_accounts.csv
```

### File Locations

```
project/
├── google_workspace/
│   └── create_google_users.py       # Main script
├── config.yaml                       # Configuration
├── service_account.json              # Google credentials
├── students.csv                      # Input data
├── created_accounts.csv              # Success log
└── failed_accounts.csv               # Failure log
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 22, 2026 | Initial release with comprehensive user guide |

---

## Support & Feedback

For issues, questions, or suggestions:

- **Author:** William Hamilton
- **Documentation:** This user guide
- **Testing:** Comprehensive test suite available in `google_workspace/tests/`

**Remember:** Always dry-run first, test with small batches, and keep backups! 🚀

---

*Last Updated: February 22, 2026*

