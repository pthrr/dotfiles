---
name: security-audit
description: Audit the security of infrastructure (hosts, networks, clusters and the services on them) by published methods - NIST SP 800-115 for the process, OSSTMM 3 for the attack surface, MITRE ATT&CK for attack paths, CVSS v4.0 and NIST SP 800-30 for severity and risk. Compares what the owner declares with what the system does, from every direction an attacker can reach it, and reports evidence-backed findings and what was not tested. Read-only by default. Use when asked to audit, assess or review the security of a server, network, firewall or cluster. Not for application code; use security-review for that.
---

# Security audit of infrastructure

The agent audits infrastructure the way the published methods describe, and
each step below names the source it follows (listed under Sources). The method
holds on any operating system and with any tools: use whatever the audited
system and the agent's own machine offer, and prefer the system's own account
of its state over a scanner's guess.

By default the audit changes nothing. Fixes are recommendations; the owner
applies them through their own change process.

## Terms

From OSSTMM 3, in brief:

- **Vector**: a direction of interaction, from one position to another, such
  as internet to edge, one network segment to another, a workload to its
  host, or the host to the internet (egress). Each vector is audited on its
  own (OSSTMM 2.1).
- **Channel**: the medium of interaction. Infrastructure audits cover data
  networks, and wireless and telecommunication lines where they exist. The
  human and physical channels are out of scope unless the owner adds them
  (OSSTMM 2.2).
- **Porosity**: the openings in the separation between an asset and a
  threat, seen from one vector (OSSTMM 1.1):
  - visibility: what the vector can learn exists
  - access: what it can interact with
  - trust: what accepts interaction from it without authentication, for
    example by source address, network membership or a shared credential
- **Controls**, ten kinds (OSSTMM 1.2). Five act on the interaction:
  - authentication
  - indemnification
  - resilience: protection holds when a part fails
  - subjugation: interaction is possible only in the ways the owner defined
  - continuity: service holds when a part fails

  Five protect the asset once a threat is present: non-repudiation,
  confidentiality, privacy, integrity and alarm. A control with flaws can
  add attack surface instead of removing it.
- **Limitations**, the five kinds of failure (OSSTMM 1.4):
  - vulnerability: denies the entitled, admits the unentitled, or lets
    someone hide themselves or assets
  - weakness: defeats one of the five interaction controls
  - concern: defeats one of the five protection controls
  - exposure: makes a target or asset visible without need
  - anomaly: something no one can account for

  One flaw may be several kinds at once.
- **Attack surface**: whatever part of the scope is unprotected from a given
  vector (OSSTMM 2.1).

## 1. Define the audit

NIST SP 800-115 section 6 and OSSTMM 2.1. Write down:

- **Assets**: what is worth protecting, such as data, credentials, the
  ability to change the system, and its availability.
- **Engagement zone and scope**: the components around the assets. Include
  the dependencies they need to operate, such as upstream DNS, certificate
  authorities, the ISP and power. A dependency the owner does not control is
  examined only from the owner's side, never tested.
- **Vectors**: each one, named as source and target.
- **Channels** in scope.
- **Test type**: tandem by default (OSSTMM 2.3). The owner knows of the audit
  and the agent may read everything. That tests the controls thoroughly, but
  not how well the owner responds to a surprise.
- **Rules of engagement**: the defaults at the end of this file, plus
  whatever the owner changes.
- **Vantage points**: where the agent can actually test each vector from. A
  vector it cannot reach, such as the public internet from inside the
  network, is examined from configuration and marked "not tested".

Present this audit plan to the owner, and test nothing until they approve it
(800-115 section 6.5). Where a repository's agent rules require an approved
plan before acting, the audit plan is that plan.

## 2. Establish the intent

OSSTMM 2.7 asks how the system works, how that differs from what its owner
believes, and how it needs to work. Answering the second question needs the
owner's belief written down first. Take it from the system's declaration
(configuration as code, documentation, rulesets, the posture review of
OSSTMM 6.2 module A.1), and ask the owner where the declaration is silent.

For every vector, record what should be visible, what accessible and what
trusted. Every later observation is compared with this record:

- a difference from it is a finding
- anything that neither the declaration nor the owner accounts for is an
  anomaly

## 3. Examine

These are the review techniques of NIST SP 800-115 section 3. Read, without
interacting:

- the documentation
- the rulesets of every filtering point, in both address families and both
  directions
- the live system configuration
- the logs
- the integrity of files

Examine the live configuration, not only the declared one: OSSTMM 2.5 warns
that configuration is not operation. A setting that is declared but not
in effect is a finding.

Read secrets' metadata (location, owner, permissions, who can reach them),
never their contents; exposure is proven without the value.

## 4. Test from each vector

These are the target identification techniques of NIST SP 800-115 section 4,
following OSSTMM's interaction phase (6.2, modules B.4 to B.7). Test external
vectors first and internal ones after (800-115 section 2.4.1).

From each vantage point:

- discover what answers
- identify the ports and services
- find each service's version and known vulnerabilities

That measures the vector's visibility and access. Then find its trusts: what
the target admits because of where a request comes from, rather than who
sends it.

Know first what reacts to probing (OSSTMM module A.3), such as rate limits,
bans and intrusion detection. Otherwise a probe that gets blocked looks like
a service that is closed.

Record every test as you run it (800-115 section 7.2): the time, the vector
and vantage point, the command, the source address, and the result. Keep this
log in the agent's scratch space or where the owner says, never on the
target. It is sensitive: it maps the system's weaknesses (800-115 section
7.4).

## 5. Verify controls and classify limitations

For every point of access and trust, find the controls that guard it and
check that each one works (OSSTMM module B.7). Give each failure its
limitation type and the control it defeats.

Privileges and quarantine (OSSTMM modules D.14 and D.15) are examined in
configuration:

- what each process, user and workload may do
- how it could escalate to root or to administrator of the cluster
- what isolates it from the others

Count a flaw once. Two observations of the same component with the same
effect are one finding (OSSTMM 1.4). A limitation stays on the attack surface
even when the owner accepts it; record it as accepted, with the owner's
reason (OSSTMM 1.4).

## 6. Corroborate

A single probe and its reply prove little (OSSTMM 2.5). A target that does
not answer one kind of request may answer another kind. Confirm a result by
three means (OSSTMM 2.6):

- the target's own state, such as its listening sockets, counters and logs
- the environment the probe passed through, such as a proxy, NAT or a
  firewall answering for the target
- a second, different interaction

Scanner hits and version-based vulnerability matches are leads. Confirm them
by examining the system by hand. A second tool is not enough, because tools
share false positives (800-115 section 7.3).

Mark each finding **confirmed** or **suspected**. For a suspected one, name
the error it may carry (OSSTMM 2.8). Common ones in infrastructure:

- false positive or false negative
- specter: the reply came from something other than the target
- indiscretion: the answer depends on when it was asked, for example before
  or after a rate limit set in
- falsification: the answer depends on the vector or address family
- sampling: only part of the scope was tested
- constraint: the tool could not see it

## 7. Chain attack paths

Build paths with the tactics of MITRE ATT&CK Enterprise. Start from each
point where a vector gets in (Initial Access, TA0001). Ask which tactic could
follow:

- Execution (TA0002)
- Persistence (TA0003)
- Privilege Escalation (TA0004)
- Stealth (TA0005)
- Defense Impairment (TA0112)
- Credential Access (TA0006)
- Discovery (TA0007)
- Lateral Movement (TA0008)
- Collection (TA0009)
- Command and Control (TA0011)
- Exfiltration (TA0010)
- Impact (TA0040)

Keep asking until the path reaches an asset, or a working control stops it.
Exposure findings feed Reconnaissance (TA0043).

A path is confirmed only when every step in it is confirmed. Two limitations
that are minor on their own can together form a severe path. A path that a
control stops shows what that control is worth.

Close the tests with the alert and log review (OSSTMM module D.17): did the
audit's own probes appear where someone would notice them? Probes that left
no trace are findings against the alarm and non-repudiation controls.

## 8. Rate

- **Single vulnerabilities** with a published identifier get a severity under
  CVSS v4.0. Use the advisory's base metrics, and adjust them with the
  environmental metrics for this deployment. For example, the attack vector
  becomes adjacent when only the local network reaches the service, and the
  security requirements follow the value of the asset. Label the result
  CVSS-BE, or CVSS-BTE when exploit maturity is known. CVSS measures
  severity, not risk.
- **Every path and limitation** gets a risk under NIST SP 800-30 Rev. 1:
  likelihood × impact. Likelihood comes from the vector's reach and how easy
  each step is, and impact from the assets at the end. Both use its
  five-level scale: very low, low, moderate, high, very high. The report
  ranks by this risk.

OSSTMM deliberately leaves risk out of its metrics, so keep the two apart:
the limitation type says what fails, and the rating says how much that
matters here.

## 9. Report

NIST SP 800-115 section 8. The report goes to the owner only:

1. Test type, scope, vectors, channels, vantage points and the dates of the
   audit.
2. Attack paths, ordered by risk. Each path is a chain of finding references
   with its status.
3. Findings, ordered by risk. Each one gives:
   - its limitation type, its vector and the control it defeats
   - the evidence: a reference to the test log entry, the command and an
     excerpt of the output, never a secret value
   - whether it is confirmed or suspected, with the possible error if
     suspected
   - its root cause
   - the recommended fix, technical and in the owner's process (800-115
     section 8.1)
   - where the system declares that fix, when it is declared as code
4. Accepted limitations, with the owner's reasons.
5. Not tested: every vector, channel, module or technique the audit left out,
   and why (OSSTMM 2.7).
6. Fixes, ordered by risk removed per effort. Before recommending a new
   control, check that it adds no attack surface of its own (OSSTMM 1.2).

## Rules of engagement

These are the defaults. The owner can widen them in the audit plan:

- The audit is a tandem test and read-only. It changes no configuration,
  restarts nothing and installs nothing on the target.
- It does nothing that switches, changes, overloads or starves a resource the
  target depends on (the disruptive part of OSSTMM's intervention phase,
  module D.16).
- It skips 800-115's validation by exploitation (section 5): no password
  cracking, no exploit beyond showing that something is reachable, and no
  social engineering.
- It tests only targets the owner controls and named. Third-party
  infrastructure is examined from the owner's side only.
- It never reads a secret's value, and never reports one.
- Signs of a real intruder stop the audit, and the agent reports them to the
  owner at once (800-115 section 7.2).
- A fix waits for the owner's change process, even when it is urgent
  (800-115 section 7.2).

Whatever these rules leave out appears in the report under "Not tested".

## Sources

- NIST SP 800-115, *Technical Guide to Information Security Testing and
  Assessment*, 2008:
  <https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-115.pdf>
- ISECOM, *OSSTMM 3.02, Open Source Security Testing Methodology Manual*,
  2010, CC BY-NC-ND 3.0 and the Open Methodology License. It is applied here,
  not reproduced: <https://www.isecom.org/OSSTMM.3.pdf>
- MITRE ATT&CK, Enterprise tactics, v20:
  <https://attack.mitre.org/tactics/enterprise/>
- FIRST, *CVSS v4.0 Specification*:
  <https://www.first.org/cvss/v4.0/specification-document>
- NIST SP 800-30 Rev. 1, *Guide for Conducting Risk Assessments*, 2012,
  appendices G to I: <https://csrc.nist.gov/pubs/sp/800/30/r1/final>
