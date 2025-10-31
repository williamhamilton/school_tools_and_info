# Cloud Data Backup Strategy for My Primary School

**Prepared for:** Senior Management Team  
**Date:** October 2025  

---

## 1. Executive Summary

My Primary School uses **Google Workspace for Education** (Drive, Docs, Sheets, and Slides) and **Microsoft 365** (Outlook and Office applications).  
While these platforms provide strong reliability and redundancy, they do not offer comprehensive data backups.  

If data is deleted, overwritten, or an account is removed, recovery is often only possible for a limited time.  
This paper outlines the risks, identifies gaps in protection, and recommends practical steps and backup solutions suited to New Zealand primary schools.

---

## 2. Current Environment

The school operates a cloud-first model, with minimal local infrastructure.  
Teachers and staff rely heavily on cloud-based tools for teaching and administration.

- **Google Workspace for Education** – used for Drive, Docs, Sheets, Slides, and Shared Drives.  
- **Microsoft 365** – used primarily for Outlook email, with some use of Word, Excel, and PowerPoint.  
- Staff store critical files, planning documents, and communication records in these systems.

---

## 3. Why Backups Still Matter

Although Google and Microsoft provide high system availability, they do not fully protect against human error, malicious actions, or accidental deletions.  
Key risks include:

- Deleted or overwritten files beyond retention limits  
- Ransomware or synchronisation corruption spreading through cloud drives  
- Data loss when staff leave and accounts are deleted  
- Incomplete recovery under standard retention settings

---

## 4. Risks to the School

Without independent backups, the school faces potential loss of teaching materials, communication records, and administrative data.  
This can result in downtime, reputational harm, and possible non-compliance with the **Privacy Act 2020** and **Ministry of Education data retention expectations**.

---

## 5. Backup Goals

A cloud backup strategy for My Primary School should:

- Ensure data recoverability independent of Google and Microsoft retention settings  
- Allow quick restoration of individual files or emails  
- Meet compliance and governance expectations  
- Remain cost-effective and simple to manage  

---

## 6. Backup Options

Three broad approaches are available:

### A. Manual / Native Methods
Using Google Takeout or Microsoft 365 export tools to manually back up data.  
These are time-consuming and rely on staff consistency, making them unsuitable for ongoing protection.

### B. Third-Party Cloud-to-Cloud Backup
Purpose-built cloud backup services automatically back up Google Workspace and Microsoft 365 data daily.  
They allow granular recovery (emails, individual files, or whole accounts) through a web portal.  

**Recommended vendors suitable for schools:**
- Backupify for Education  
- Afi.ai  
- SpinBackup  
- Dropsuite  
- Veeam Backup for Microsoft 365 (can include Google via partner tools)  
- Redstor for Education (available in NZ via resellers)

### C. Hybrid Policy Approach
Combine retention policies in Google Admin and Microsoft 365 with a third-party backup for critical data.  
This provides short-term coverage through retention and long-term resilience through independent backup.

---

## 7. Recommended Approach for My Primary School

The school should adopt a **cloud-to-cloud backup service** that covers both Google Workspace and Microsoft 365.  

**Key actions include:**
1. Select a backup vendor offering NZ data residency or strong compliance guarantees.  
2. Retain backups for **five to seven years, consistent with New Zealand public-sector record-keeping standards**.  
3. Include Shared Drives, teacher mailboxes, and key admin accounts.  
4. Schedule annual restore testing.  
5. Document the backup and recovery process in the school’s ICT policy.

---

## 8. Implementation Plan

| Phase | Action | Responsibility |
|-------|---------|----------------|
| 1 | Review Google Admin and M365 retention settings | IT Support / Principal |
| 2 | Evaluate 2–3 backup vendors and request quotes | IT Support |
| 3 | Pilot backup on selected accounts | IT Support |
| 4 | Roll out full backup coverage | IT Support / Principal |
| 5 | Train admin staff and test restore process | Principal / DP Administration |

---

## 9. Conclusion

A reliable cloud backup strategy is essential to safeguard the school’s teaching materials, communication records, and compliance obligations.  
Implementing an automated backup for Google Workspace and Microsoft 365 provides cost-effective protection and ensures data can be restored quickly if lost or compromised.

---

## 10. References

- [New Zealand Privacy Act 2020](https://www.privacy.org.nz/)  
- [Ministry of Education: Information and Data Management](https://www.education.govt.nz/)  
- [N4L Cybersecurity Guidance](https://www.n4l.co.nz/)  
- [Google Workspace for Education Help Centre](https://support.google.com/edu)  
- [Microsoft 365 Education Support](https://learn.microsoft.com/en-us/education/)  
- [Redstor for Education NZ](https://www.redstor.com/education)  
- [Public Records Act 2005](https://www.legislation.govt.nz/act/public/2005/0040/latest/DLM345529.html)  
- [Inland Revenue: Retention of Business and Tax Records](https://www.ird.govt.nz/records)  
- [Audit NZ: Record Keeping Guidance for Schools](https://auditnz.parliament.nz/good-practice/schools)
