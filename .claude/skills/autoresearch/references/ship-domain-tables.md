# Ship Domain Tables

Per-domain action tables for each phase of /autoresearch:ship. Referenced from `ship-workflow.md`.

## Phase 2: Inventory Checks

| Type | Inventory Checks |
|------|-----------------|
| code-pr | Changed files, test status, lint status, PR description, review status |
| code-release | Version tag, changelog, migration status, dependency audit |
| deployment | Build status, env vars, infra health, rollback plan |
| content | Word count, links checked, images present, metadata/frontmatter |
| marketing-email | Subject line, preview text, links, unsubscribe, CAN-SPAM compliance |
| marketing-campaign | Assets ready, tracking pixels, UTM params, A/B variants |
| sales | Pricing current, branding consistent, contact info, CTA clear |
| research | Citations complete, methodology documented, data sources linked |
| design | Formats exported, responsive variants, accessibility checked |

## Phase 3: Domain-Specific Checklists

### Code Checklists

**code-pr:**
- [ ] All tests pass (`npm test` / `pytest` / language-specific)
- [ ] Lint clean (no errors, warnings acceptable)
- [ ] Type check passes (if applicable)
- [ ] PR description explains the "why"
- [ ] No secrets in diff (`git diff --cached | grep -i "password\|secret\|api_key"`)
- [ ] No TODO/FIXME in new code (or documented as intentional)
- [ ] Breaking changes documented (if any)
- [ ] Reviewer assigned or review complete

**code-release:**
- [ ] All code-pr checks pass
- [ ] Version bumped in package.json/pyproject.toml/Cargo.toml
- [ ] CHANGELOG updated with release notes
- [ ] Migration scripts tested (if DB changes)
- [ ] Dependency audit clean (`npm audit` / `pip audit`)
- [ ] Tag created matching version

**deployment:**
- [ ] All code-release checks pass
- [ ] Build succeeds in CI
- [ ] Environment variables set for target env
- [ ] Health check endpoint responds
- [ ] Rollback plan documented
- [ ] Monitoring/alerting configured
- [ ] Feature flags set correctly

### Content Checklists

**content (blog/docs):**
- [ ] Title present and descriptive
- [ ] No broken links (internal or external)
- [ ] Images have alt text
- [ ] Meta description present (≤160 chars)
- [ ] No placeholder text ("Lorem ipsum", "TODO", "TBD")
- [ ] Grammar/spell check passes
- [ ] Publish date set
- [ ] Author attribution present

### Marketing Checklists

**marketing-email:**
- [ ] Subject line present (≤60 chars recommended)
- [ ] Preview text set
- [ ] All links working and tracked (UTM parameters)
- [ ] Unsubscribe link present and functional
- [ ] Physical address included (CAN-SPAM)
- [ ] Responsive on mobile (test render)
- [ ] Plain text fallback exists
- [ ] Sender name and reply-to configured

**marketing-campaign:**
- [ ] All creative assets finalized
- [ ] Tracking pixels/UTM parameters configured
- [ ] Target audience defined and segmented
- [ ] Budget allocated and approved
- [ ] Landing page live and tested
- [ ] A/B test variants set (if applicable)
- [ ] Schedule confirmed

### Sales Checklists

**sales (deck/proposal):**
- [ ] Company/prospect name correct throughout
- [ ] Pricing is current and approved
- [ ] Contact information accurate
- [ ] Branding consistent (logos, colors, fonts)
- [ ] No competitor names misspelled
- [ ] CTA is clear and actionable
- [ ] Attached case studies/testimonials current
- [ ] File format appropriate (PDF for external, editable for internal)

### Research Checklists

**research (paper/report):**
- [ ] Abstract/executive summary present
- [ ] All citations properly formatted
- [ ] Data sources linked and accessible
- [ ] Methodology section complete
- [ ] Figures/charts labeled and referenced
- [ ] Conclusion addresses stated hypothesis
- [ ] Acknowledgments included
- [ ] No placeholder references ("[citation needed]")

### Design Checklists

**design (assets/mockups):**
- [ ] All requested formats exported (PNG, SVG, PDF)
- [ ] Responsive variants provided (mobile, tablet, desktop)
- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] No placeholder images or text
- [ ] Source files organized and named
- [ ] Brand guidelines followed
- [ ] Handoff notes/specs documented

## Phase 5: Dry-Run Actions

| Type | Dry-Run Action |
|------|---------------|
| code-pr | `gh pr create --draft` or preview PR diff |
| code-release | Create tag locally (don't push), preview changelog |
| deployment | Build Docker image, run health checks locally |
| content | Preview render, check all links resolve |
| marketing-email | Send test email to sender's own address |
| marketing-campaign | Preview in ad platform, estimate reach |
| sales | Preview PDF render, check all pages |
| research | Export to final format, check pagination |
| design | Preview all exported formats, check dimensions |

## Phase 6: Ship Actions

| Type | Ship Action |
|------|------------|
| code-pr | `gh pr create` with full description, request reviewers |
| code-release | `git tag`, `git push --tags`, create GitHub release |
| deployment | `git push` to deploy branch, trigger CI/CD, or `kubectl apply` |
| content | Publish via CMS API, or commit to content branch |
| marketing-email | Send via ESP API (SendGrid, Mailchimp, etc.) |
| marketing-campaign | Activate campaign in ad platform |
| sales | Send email with attachment, or share link |
| research | Upload to repository, submit to journal/platform |
| design | Upload to asset library, share with stakeholders |

**Safety rails:**
- Confirm target (staging vs production, draft vs publish)
- Log the exact command/action taken
- Record timestamp
- Capture any response/confirmation IDs

## Phase 7: Verification Checks

| Type | Verification |
|------|-------------|
| code-pr | PR created, CI running, link accessible |
| code-release | Tag visible, release page published, assets attached |
| deployment | Health endpoint returns 200, no error spike in logs |
| content | Page loads, links work, appears in sitemap |
| marketing-email | Delivery rate > 95%, no bounce spike |
| marketing-campaign | Ads serving, landing page loading, tracking firing |
| sales | Email delivered, link tracking active |
| research | Accessible via URL/DOI, properly indexed |
| design | Assets downloadable, correct dimensions |

**Post-ship monitoring (with `--monitor N` flag):**
```
FOR N minutes:
  Check health metrics every 60 seconds
  IF anomaly detected → ALERT user immediately
  Log metrics to ship-log
```

## Phase 8: Log Format

**Log format (append to `ship-log.tsv`):**
```tsv
timestamp	type	target	checklist_score	dry_run	shipped	verified	duration	notes
2026-03-16T14:30:00Z	code-pr	#42	18/18	pass	pass	pass	4m32s	auth feature PR
```

**Summary output:**
```
=== Ship Complete ===
Type: [shipment type]
Target: [where it went]
Checklist: [P/T] items passed
Duration: [total time]
Status: SHIPPED ✓
```

## Rollback Protocol Actions

| Type | Rollback Action |
|------|----------------|
| code-pr | Close PR: `gh pr close` |
| code-release | Delete tag: `git tag -d` + `git push --delete origin` |
| deployment | Revert deploy: `git revert` or `kubectl rollback` |
| content | Unpublish/revert to draft |
| marketing-email | Cannot rollback (flag as "sent") |
| marketing-campaign | Pause campaign in ad platform |
| sales | Send correction/follow-up |
| research | Request retraction or update |
| design | Revert to previous version in asset library |

**Non-reversible actions** (email, some publications) are flagged before Phase 6 ship action.
