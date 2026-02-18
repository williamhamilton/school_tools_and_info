"""
I really should document this script!
"""
# ---------------------------------------------------------------------------------------------------------------------
__author__ = "William Hamilton"
__python__ = ""
__created__ = "18/02/2026"
__copyright__ = "Copyright © 2026~"
__license__ = ""
__ToDo__ = """

"""
import pytest
from unittest.mock import patch
import argparse
import yaml
from google_workspace.create_google_users import main

# -------------------------------
# Failure Scenario Fixtures
# -------------------------------

@pytest.fixture
def failure_csv(tmp_path):
    """CSV with intentional errors: missing names and invalid emails"""
    csv_path = tmp_path / "students_failure.csv"
    csv_path.write_text(
        "First Name,Last Name,Email,Class\n"
        ",Smith,missingfirst@example.com,Year1\n"  # Missing first name
        "John,,missinglast@example.com,Year2\n"    # Missing last name
        "Jane,Doe,invalidemail,Year3\n"            # Invalid email
    )
    return csv_path

@pytest.fixture
def failure_config(tmp_path, failure_csv):
    """Minimal config YAML for testing failure case"""
    config_path = tmp_path / "config.yaml"
    config_content = f"""
script:
  csv_file: "{failure_csv}"
  dry_run: True
  success_log: "{tmp_path}/success.csv"
  failure_log: "{tmp_path}/failure.csv"
  include_password_in_email: True
google:
  org_unit_path: "/Students"
  auto_generate_email: False
  default_domain: "school.nz"
  service_account_file: "fake.json"
  delegated_admin: "admin@school.nz"
smtp:
  server: "smtp.school.nz"
  port: 587
  user: "itadmin@school.nz"
  recipient: "teacher@school.nz"
  cc: ["it@school.nz"]
"""
    config_path.write_text(config_content)
    return config_path

# -------------------------------
# Success Scenario Fixtures
# -------------------------------

@pytest.fixture
def success_csv(tmp_path):
    """CSV with valid student entries"""
    csv_path = tmp_path / "students_success.csv"
    csv_path.write_text(
        "First Name,Last Name,Email,Class\n"
        "Alice,Smith,alice.smith@school.nz,Year1\n"
        "Bob,Jones,bob.jones@school.nz,Year2\n"
    )
    return csv_path

@pytest.fixture
def success_config(tmp_path, success_csv):
    config_path = tmp_path / "config.yaml"
    config_content = f"""
script:
  csv_file: "{success_csv}"
  dry_run: True
  success_log: "{tmp_path}/success.csv"
  failure_log: "{tmp_path}/failure.csv"
  include_password_in_email: True
google:
  org_unit_path: "/Students"
  auto_generate_email: False
  default_domain: "school.nz"
  service_account_file: "fake.json"
  delegated_admin: "admin@school.nz"
smtp:
  server: "smtp.school.nz"
  port: 587
  user: "itadmin@school.nz"
  recipient: "teacher@school.nz"
  cc: ["it@school.nz"]
"""
    config_path.write_text(config_content)
    return config_path

# -------------------------------
# Failure Test
# -------------------------------

@patch("create_google_users.send_batch_email")
@patch("create_google_users.create_google_service")
@patch("argparse.ArgumentParser.parse_args", return_value=argparse.Namespace(csv=None, ou=None, recipient=None, dry_run=True))
def test_main_failure_cases(mock_args, mock_service, mock_send_email, failure_config, monkeypatch, tmp_path):
    """Run main with CSV containing failures and check failure count."""
    monkeypatch.setattr(
        "create_google_users.load_config",
        lambda config_file=None: yaml.safe_load(failure_config.read_text())
    )

    main()

    mock_send_email.assert_called_once()
    students_sent = mock_send_email.call_args[0][1]
    assert len(students_sent) == 0

    failure_log_path = tmp_path / "failure.csv"
    assert failure_log_path.exists()
    with open(failure_log_path) as f:
        lines = f.readlines()
    assert len(lines) == 4  # header + 3 errors

# -------------------------------
# Success Test
# -------------------------------


@patch("create_google_users.send_batch_email")
@patch("create_google_users.create_google_service")
@patch("argparse.ArgumentParser.parse_args", return_value=argparse.Namespace(csv=None, ou=None, recipient=None, dry_run=True))
def test_main_success_cases(mock_args, mock_service, mock_send_email, success_config, monkeypatch, tmp_path):
    """Run main with valid CSV and check success log"""
    monkeypatch.setattr(
        "create_google_users.load_config",
        lambda config_file=None: yaml.safe_load(success_config.read_text())
    )

    main()

    # All students should be sent in email
    mock_send_email.assert_called_once()
    students_sent = mock_send_email.call_args[0][1]
    assert len(students_sent) == 2
    emails = [s['Email'] for s in students_sent]
    assert "alice.smith@school.nz" in emails
    assert "bob.jones@school.nz" in emails

    # Success log should exist and have 3 lines (header + 2 students)
    success_log_path = tmp_path / "success.csv"
    assert success_log_path.exists()
    with open(success_log_path) as f:
        lines = f.readlines()
    assert len(lines) == 3


# -------------------------------
# Mixed CSV Test
# -------------------------------

@pytest.fixture
def mixed_csv(tmp_path):
    """CSV with both valid and invalid rows"""
    csv_path = tmp_path / "students_mixed.csv"
    csv_path.write_text(
        "First Name,Last Name,Email,Class\n"
        "Alice,Smith,alice.smith@school.nz,Year1\n"  # valid
        ",Brown,nobrown@example.com,Year2\n"          # missing first name
        "Bob,Jones,bob.jones@school.nz,Year3\n"      # valid
        "Jane,Doe,invalidemail,Year4\n"              # invalid email
    )
    return csv_path

@pytest.fixture
def mixed_config(tmp_path, mixed_csv):
    config_path = tmp_path / "config.yaml"
    config_content = f"""
script:
  csv_file: "{mixed_csv}"
  dry_run: True
  success_log: "{tmp_path}/success.csv"
  failure_log: "{tmp_path}/failure.csv"
  include_password_in_email: True
google:
  org_unit_path: "/Students"
  auto_generate_email: False
  default_domain: "school.nz"
  service_account_file: "fake.json"
  delegated_admin: "admin@school.nz"
smtp:
  server: "smtp.school.nz"
  port: 587
  user: "itadmin@school.nz"
  recipient: "teacher@school.nz"
  cc: ["it@school.nz"]
"""
    config_path.write_text(config_content)
    return config_path

@patch("create_google_users.send_batch_email")
@patch("create_google_users.create_google_service")
@patch(
    "argparse.ArgumentParser.parse_args",
    return_value=argparse.Namespace(
        csv=None, ou=None, recipient=None, dry_run=True
    )
)
def test_main_mixed_cases(mock_args, mock_service, mock_send_email, mixed_config, monkeypatch, tmp_path):
    """Run main with mixed CSV: some valid, some invalid rows"""
    monkeypatch.setattr(
        "create_google_users.load_config",
        lambda config_file=None: yaml.safe_load(mixed_config.read_text())
    )

    main()

    # Check that only valid students are sent in the email
    mock_send_email.assert_called_once()
    students_sent = mock_send_email.call_args[0][1]
    assert len(students_sent) == 2
    emails = [s['Email'] for s in students_sent]
    assert "alice.smith@school.nz" in emails
    assert "bob.jones@school.nz" in emails

    # Success log should contain header + 2 students
    success_log_path = tmp_path / "success.csv"
    assert success_log_path.exists()
    with open(success_log_path) as f:
        lines = f.readlines()
    assert len(lines) == 3

    # Failure log should contain header + 2 errors
    failure_log_path = tmp_path / "failure.csv"
    assert failure_log_path.exists()
    with open(failure_log_path) as f:
        lines = f.readlines()
    assert len(lines) == 3  # header + 2 failed rows






