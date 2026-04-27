# Example CSV Files

This directory contains example CSV files showing different use cases for the Google Workspace student account creation script.

---

## Available Example Files

### 1. **example_students_with_passwords.csv**
**Use Case:** Set specific passwords from CSV, don't force change on first login

**CSV Format:**
```csv
First Name,Last Name,Email,Password,Class
Alice,Smith,alice.smith@school.nz,Welcome2026!,Year 7
Bob,Jones,bob.jones@school.nz,School123Pass,Year 7
```

**Config Settings:**
```yaml
script:
  csv_file: "example_students_with_passwords.csv"
  force_password_change_at_login: false  # Users keep their passwords
```

**Result:** 
- Users created with passwords from CSV
- Users can log in immediately
- No password change required

**Best For:** Pre-assigned passwords, service accounts, immediate access needed

---

### 2. **example_students_autogen_passwords.csv**
**Use Case:** Auto-generate secure random passwords for all users

**CSV Format:**
```csv
First Name,Last Name,Email,Class
Alice,Smith,alice.smith@school.nz,Year 7
Bob,Jones,bob.jones@school.nz,Year 7
```

**Config Settings:**
```yaml
script:
  csv_file: "example_students_autogen_passwords.csv"
  password_length: 12  # Or 16 for higher security
  force_password_change_at_login: true  # Recommended for security
```

**Result:** 
- Each user gets a unique random password (e.g., `xK9pL#mQ2vR`)
- Passwords sent via email notification
- Users must change password on first login (if configured)

**Best For:** New student intake, maximum security, random password distribution

---

### 3. **example_students_mixed_passwords.csv**
**Use Case:** Some users with preset passwords, others with auto-generated

**CSV Format:**
```csv
First Name,Last Name,Email,Password,Class
Alice,Smith,alice.smith@school.nz,Welcome2026!,Year 7
Bob,Jones,bob.jones@school.nz,,Year 7
Charlie,Brown,charlie.brown@school.nz,MySecure2026,Year 8
```

**Config Settings:**
```yaml
script:
  csv_file: "example_students_mixed_passwords.csv"
  password_length: 12
  force_password_change_at_login: false  # Optional
```

**Result:** 
- Alice gets `Welcome2026!` (from CSV)
- Bob gets auto-generated password (e.g., `aB7#qW9nM4pL`)
- Charlie gets `MySecure2026` (from CSV)

**Best For:** Partial password control, migration scenarios, mixed requirements

---

### 4. **example_students_autogen_emails.csv**
**Use Case:** Auto-generate emails from student names

**CSV Format:**
```csv
First Name,Last Name,Email,Class
Alice,Smith,,Year 7
Bob,Jones,,Year 7
```

**Config Settings:**
```yaml
google:
  auto_generate_email: true  # IMPORTANT: Must be enabled!
  default_domain: "yourschool.school.nz"

script:
  csv_file: "example_students_autogen_emails.csv"
```

**Result:** 
- Alice Smith → `alice.smith@yourschool.school.nz`
- Bob Jones → `bob.jones@yourschool.school.nz`
- Passwords are auto-generated

**Best For:** Bulk user creation with standardized email format

---

## CSV Column Specifications

### Required Columns

| Column | Required | Description |
|--------|----------|-------------|
| `First Name` | ✅ Yes | Student's first name |
| `Last Name` | ✅ Yes | Student's last name |
| `Email` | ⚠️ Conditional | Required UNLESS `auto_generate_email: true` |
| `Password` | ❌ No | Optional - auto-generated if not provided |
| `Class` | ❌ No | Optional - for grouping in email reports |

### Column Name Requirements

- ✅ Column headers are **case-sensitive**
- ✅ Use exact names: `First Name`, `Last Name`, `Email`, `Password`, `Class`
- ❌ Don't use: `FirstName`, `first_name`, `First`, etc.

---

## Password Requirements

If providing passwords in CSV, they must meet Google's requirements:

- ✅ **Minimum 8 characters**
- ✅ **Recommended:** 12+ characters
- ✅ **Mix of:**
  - Uppercase letters (A-Z)
  - Lowercase letters (a-z)
  - Numbers (0-9)
  - Symbols (!@#$%^&*)

### Good Password Examples:
- `Welcome2026!`
- `School@Pass123`
- `MySecure#2026`
- `Student!Pass99`

### Bad Password Examples:
- ❌ `password` - Too simple
- ❌ `12345678` - No letters
- ❌ `alice` - Too short, no complexity
- ❌ `Alice2026` - No special characters

---

## Quick Start Guide

### Step 1: Choose Your Example File

Copy the appropriate example for your use case:

```bash
# For preset passwords (no forced change)
cp example_students_with_passwords.csv students.csv

# For auto-generated passwords
cp example_students_autogen_passwords.csv students.csv

# For mixed approach
cp example_students_mixed_passwords.csv students.csv

# For auto-generated emails
cp example_students_autogen_emails.csv students.csv
```

### Step 2: Edit with Your Data

Open in Excel, Google Sheets, or text editor:
- Replace example names with real student names
- Update email addresses for your domain
- Add/modify passwords as needed
- Update class/year groups

### Step 3: Configure Script

Edit `config.yaml`:
```yaml
script:
  csv_file: "students.csv"
  force_password_change_at_login: false  # Adjust as needed
```

### Step 4: Test with Dry Run

Always test first!
```bash
python google_workspace/create_google_users.py --dry-run
```

### Step 5: Run Production

If dry-run looks good:
```bash
python google_workspace/create_google_users.py
```

---

## Tips & Best Practices

### 📝 CSV Editing

- ✅ **Use UTF-8 encoding** when saving
- ✅ **Avoid special characters** in names (accents are OK)
- ✅ **Remove empty rows** at the end
- ✅ **Check for duplicates** before running
- ✅ **Backup your CSV** before editing

### 🔒 Security

- ✅ **Never commit CSV files** with real data to version control
- ✅ **Store passwords securely** after creation
- ✅ **Delete password files** after distribution
- ✅ **Use strong passwords** (12+ characters)
- ✅ **Consider forcing password change** for initial distribution

### ✅ Testing

- ✅ **Always dry-run first** with real data
- ✅ **Test with 1-2 users** before bulk creation
- ✅ **Verify in Google Admin Console** after creation
- ✅ **Test login** with sample accounts
- ✅ **Review logs** for any errors

---

## Common Issues

### Issue: "Column not found: First Name"

**Problem:** CSV headers don't match expected format

**Solution:** 
- Check column headers are exactly: `First Name`, `Last Name`, `Email`, `Password`, `Class`
- Headers are case-sensitive
- Use spaces, not underscores

### Issue: Passwords rejected by Google

**Problem:** Passwords don't meet Google's requirements

**Solution:** 
- Ensure minimum 8 characters
- Add complexity: uppercase, lowercase, numbers, symbols
- Avoid common words or patterns

### Issue: Emails not auto-generated

**Problem:** `auto_generate_email` not enabled

**Solution:** 
```yaml
google:
  auto_generate_email: true  # Must be true!
  default_domain: "yourschool.school.nz"
```

---

## File Locations

After running the script, you'll get:

```
project/
├── example_students_with_passwords.csv    # Example CSV
├── students.csv                           # Your actual CSV
├── created_accounts.csv                   # SUCCESS LOG
├── failed_accounts.csv                    # FAILURE LOG
└── config.yaml                            # Configuration
```

---

## Need Help?

1. Check **USER_GUIDE.md** for full documentation
2. Check **PASSWORD_FROM_CSV_USAGE.md** for password feature details
3. Review **Troubleshooting** section in USER_GUIDE.md
4. Run with `--dry-run` to test safely

---

*Examples created: February 22, 2026*

