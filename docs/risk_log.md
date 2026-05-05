# PantryPilot Risk Log

## Risk Rating Scale
- **Likelihood**: Low / Medium / High
- **Impact**: Low / Medium / High
- **Priority**: Critical / Major / Minor (combined assessment)

---

## Product Risks

### R1: Inventory Entry Friction Kills Retention
- **Description**: Manual pantry entry is tedious. If users find it too burdensome, they will stop updating inventory, which degrades all downstream recommendations and reduces perceived value.
- **Likelihood**: High
- **Impact**: High
- **Priority**: Critical
- **Mitigation**:
  - Offer a quick-add checklist of common staples at onboarding
  - Auto-deduct used ingredients after guided cooking
  - (Post-MVP) Barcode scan and receipt import to minimize manual input
- **Validation**: Measure pantry item count per active user at day 7 and day 30

---

### R2: Recipe Quality and Variety Disappoints Users
- **Description**: A thin or low-quality starter recipe library reduces the planner's usefulness and trust in the app.
- **Likelihood**: Medium
- **Impact**: High
- **Priority**: Critical
- **Mitigation**:
  - Curate a minimum of 50 high-quality, tested recipes before launch
  - Cover all target persona types (family-friendly, batch-cook, beginner)
  - Allow user recipe creation and import in Plus tier
- **Validation**: Track recipe usage rate and repeat cooking frequency in first 60 days

---

### R3: Meal Planning Not Adopted as a Habit
- **Description**: If users plan once but do not return the following week, the app loses its core retention driver.
- **Likelihood**: Medium
- **Impact**: High
- **Priority**: Critical
- **Mitigation**:
  - Weekly planner reminder notification (Friday for next week, configurable)
  - Reduce plan creation time to under 3 minutes with suggestion-first UX
  - Show a "reuse last week" shortcut for low-effort replanning
- **Validation**: Week-over-week plan creation rate; target 40%+ return planning by week 4

---

### R4: Freemium Limits Set Too Low or Too High
- **Description**: If free limits are too restrictive, users churn before experiencing value. If too generous, conversion to Plus is low.
- **Likelihood**: Medium
- **Impact**: Medium
- **Priority**: Major
- **Mitigation**:
  - Hold free-only period for first 90 days to observe natural usage ceilings
  - Set limits based on observed p75 usage (e.g., most users stay under 50 items)
  - A/B test limit thresholds before committing
- **Validation**: Monitor free user item counts and recipe access frequency before setting hard limits

---

### R5: Multi-Household Coordination Complexity Creeps In Early
- **Description**: Families expect shared visibility (e.g., a partner updating the pantry), but multi-user sync adds significant technical and UX complexity.
- **Likelihood**: Medium
- **Impact**: Medium
- **Priority**: Major
- **Mitigation**:
  - Defer household sharing to post-MVP
  - Single-account model for MVP with a clear roadmap note for shared access
  - Capture demand via in-app feature request tracking
- **Validation**: Count how many users request household sharing in first 60 days

---

### R6: High Churn from Competitor Switching
- **Description**: Established apps (Mealime, Paprika, AnyList) already have user bases. Users may try PantryPilot but revert to familiar tools.
- **Likelihood**: Medium
- **Impact**: Medium
- **Priority**: Major
- **Mitigation**:
  - Differentiate on the end-to-end kitchen loop — competitors focus on one area (recipes or lists), not the full workflow
  - Emphasize waste reduction as a unique emotional hook
  - Invest in onboarding to activate value in session 1
- **Validation**: Exit survey for churned users; track top competitor mentions

---

### R7: Data Privacy Concerns Around Household Habits
- **Description**: Storing household size, dietary preferences, and daily food behavior creates privacy sensitivity, especially for family users.
- **Likelihood**: Low
- **Impact**: High
- **Priority**: Major
- **Mitigation**:
  - Minimize data collection to what is functionally necessary
  - Clear privacy policy written in plain language
  - No selling of personal data; be explicit about this in onboarding
  - On-device storage option for pantry data where feasible
- **Validation**: Privacy policy review before launch; monitor support tickets for privacy concerns

---

### R8: Notification Fatigue Reduces Engagement
- **Description**: Expiry alerts, planning reminders, and waste nudges can overwhelm users and lead to notification opt-outs or uninstalls.
- **Likelihood**: Medium
- **Impact**: Medium
- **Priority**: Major
- **Mitigation**:
  - Cap total notifications to 2 per day maximum
  - Make all notification types individually toggleable in settings
  - Use smart timing based on user behavior patterns (e.g., send reminders when user is typically active)
- **Validation**: Track notification opt-out rate; target under 15%

---

### R9: Grocery Affiliate Recommendations Erode Trust
- **Description**: If sponsored product suggestions appear in recommendations, users may question whether suggestions are based on their pantry or paid placement.
- **Likelihood**: Low
- **Impact**: High
- **Priority**: Major
- **Mitigation**:
  - Clearly label any sponsored or affiliate content
  - Never override organic recommendations with paid ones
  - Introduce affiliate features only after core trust is established (post-MVP)
- **Validation**: User sentiment on recommendation trust; NPS tracking

---

### R10: Scope Creep Delays MVP Launch
- **Description**: The feature scope is broad. Without discipline, the MVP could expand to include barcode scanning, grocery sync, multi-user support, and nutrition tracking before launch.
- **Likelihood**: High
- **Impact**: Medium
- **Priority**: Major
- **Mitigation**:
  - Strictly enforce the MVP feature list defined in features.md
  - Use a written "non-goals" section as a decision boundary in planning
  - Weekly scope review against the 90-day roadmap
- **Validation**: Track features added vs. deferred in each sprint; flag any addition not in the original MVP list

---

## Risk Summary Table

| ID | Risk | Likelihood | Impact | Priority |
|---|---|---|---|---|
| R1 | Inventory entry friction | High | High | Critical |
| R2 | Recipe quality disappoints | Medium | High | Critical |
| R3 | Planning habit not formed | Medium | High | Critical |
| R4 | Freemium limits miscalibrated | Medium | Medium | Major |
| R5 | Multi-household complexity creep | Medium | Medium | Major |
| R6 | Competitor switching | Medium | Medium | Major |
| R7 | Data privacy concerns | Low | High | Major |
| R8 | Notification fatigue | Medium | Medium | Major |
| R9 | Affiliate trust erosion | Low | High | Major |
| R10 | Scope creep delays launch | High | Medium | Major |
