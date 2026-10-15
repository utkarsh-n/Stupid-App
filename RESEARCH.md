# Nopiate — Research Synthesis & Design Spec

**Compiled 16 Aug 2026** from four parallel research passes: 7-OH pharmacology, opioid dependence & taper science, dependency-weaning app UX, and iOS 27/watchOS platform capability. Full source lists live in each section.

This is the document the app gets built from. It exists to answer one question: *given what is actually known about 7-OH, about opioid tapering, and about what makes recovery software work, what should this app do?*

Evidence tiers used throughout: **[A]** RCT/meta-analysis · **[B]** observational/mechanistic with human data · **[C]** guideline consensus or expert opinion · **[D]** widely repeated but essentially unevidenced.

---

## 0. The user

- **Baseline:** ~40–50 mg/day for about a year — 10 mg morning, 10 mg afternoon, 20 mg evening.
- **Current:** nominally 15 mg/day — a half-tablet at ~8am, ~12pm, ~5pm. No anchor dose; all three slots are equal. **See §0.1 — the real number is neither 15 nor stable.**
- **Products in rotation:** Omega Extracts 10 mg · RAW MIT 12 mg · KratomHeads 18 mg · 7-OHMIT 11 mg · BulkKratomCapsules 13 mg. Doses are approximated by splitting on the tablet score line; tablets contain fillers so they cannot be weighed for content.
- **Also holds:** Omega Extracts "Astral Glitter" powder, 95%+ purity, plus a scale. **This is the most valuable asset in the taper — see §2.4.**
- **Pattern:** fixed schedule, adhered to. Cravings are not the daily problem; they arrive when withdrawal intensifies during a step-down.
- **Off the table:** buprenorphine, benzodiazepines. Clonidine reserved for severe situations only.
- **In scope as adjuncts:** cannabis (smoked and edible), melatonin, vitamin C, magnesium, and other reasonably-indicated supplements. See §9.
- **Hardware:** iPhone + Apple Watch, paid Apple Developer account, personal build.

Consequences that should shape the app more than any general best practice:

1. **He is already past the hardest behavioral step.** The single highest-leverage pre-taper move in the literature is converting as-needed dosing to fixed-schedule dosing, because PRN dosing means every dose is triggered by an aversive state and therefore reinforces attending to that state. He already dosed on a schedule. The app does not need to fight that battle.
2. **The binding constraint is withdrawal tolerability, not impulse control.** So the app's intelligence budget goes into the withdrawal-monitoring loop and the taper engine's hold logic, not into panic buttons and distraction games. A craving tool still belongs there — but as a rough-patch utility, not the centerpiece.
3. **He is at ~33% of baseline, which is where tapers get hard for real pharmacological reasons.** See §2.2. The remaining third will take longer than the first two-thirds did, and the app has to make that feel like the plan rather than a failure.
4. **Dose precision is currently the binding problem, ahead of everything else.** §0.1.

### 0.1 The measurement problem — this outranks every other open item

Five products, five strengths, split by hand on a score line. Working the arithmetic on three half-tablets per day:

| If the day runs entirely on… | Half-dose | Daily total (nominal) |
|---|---|---|
| Omega Extracts 10 mg | 5.0 mg | **15.0 mg** |
| 7-OHMIT 11 mg | 5.5 mg | **16.5 mg** |
| RAW MIT 12 mg | 6.0 mg | **18.0 mg** |
| BulkKratomCapsules 13 mg | 6.5 mg | **19.5 mg** |
| KratomHeads 18 mg | 9.0 mg | **27.0 mg** |

**The nominal daily intake ranges from 15 to 27 mg — an 80% swing — purely from which bottle is open.** "15 mg/day" is the floor of that range, true only on all-Omega days.

Three further error sources stack on top:

- **Label inaccuracy.** Commercial 7-OH measures **32–81% of stated content** (§1.6). Applied to the range above, actual daily 7-OH is somewhere between **~4.8 mg and ~21.9 mg** — a factor of 4.6.
- **Tablet-to-tablet variance** within one bottle: **RSD 10–17%**.
- **Hand-splitting error.** Score lines do not guarantee equal halves; pharmaceutical studies routinely find hand-split halves deviating 10–20%+ by mass, and with unevenly distributed fillers the *active* split can be worse than the mass split. The 13 mg product is capsules, which have no score line at all — halving those means opening and eyeballing filler-laden powder, the least accurate format available.

**Why this is the top priority:** a 5% taper step from 15 mg is **0.75 mg**. The day-to-day noise above is several milligrams. The step size is buried inside the measurement error, which means right now the taper is not actually being tapered — it is drifting, and neither he nor the app can tell a real withdrawal signal from a brand switch. Every downstream feature (hold logic, adaptive pacing, symptom correlation) is reading noise until this is fixed.

**The fix is already in his possession: the 95%+ Astral Glitter powder.** See §2.4 for the volumetric protocol and, importantly, the crossover safety asymmetry.

---

## 1. What 7-OH is, and why it matters for the design

### 1.1 Identity
7-hydroxymitragynine is a minor oxidative metabolite of mitragynine, kratom's main alkaloid. In leaf it is a trace constituent — 0.011–0.039% dry weight, under 2% of total alkaloid content, sometimes not measurable at all. Commercial "7-OH" tablets are therefore **not extracts**; extraction from leaf is economically impossible. They are semi-synthetic: bulk mitragynine is isolated and chemically oxidized, yielding finished products up to 98% 7-OH. **[A/gov]**

This is the whole story of why 7-OH dependence differs in kind from kratom-leaf dependence. It is not exotic pharmacology — it is that a 30 mg tablet contains roughly 75–260× the 7-OH in a gram of leaf, and the bulk/bitterness ceiling that limits leaf intake is gone.

### 1.2 Receptor pharmacology
- High-affinity partial agonist at the mu-opioid receptor: hMOR EC50 **34.5 nM** vs mitragynine's 339 nM; binding affinity **9–20× higher** than mitragynine. Antagonist at delta and kappa. **[A]**
- Potency: **~10–13× morphine** in rodent antinociception, **~40–46× mitragynine**. Respiratory depression **~3–4.5× more potent than morphine**. **[A]**
- The **kappa-antagonism matters and is under-discussed.** Kappa/dynorphin signaling is the dysphoria engine. 7-OH acutely blocks it — which removes the aversive brake that limits some opioids, raising reinforcement value. When 7-OH washes out, upregulated dynorphin signaling that has been chronically antagonized goes unopposed. **Mechanistic prediction [C]:** interdose *dysphoria* should be disproportionately prominent relative to somatic symptoms. Matches the repeated clinical observation that depression during 7-OH detox is more severe than providers see in illicit-opioid detox.

### 1.3 The "G-protein biased = safer" claim is marketing, and it is wrong
7-OH shows G-protein-biased signaling with weak β-arrestin-2 recruitment, which produced the hopeful "atypical opioid, wider therapeutic window" framing now used throughout 7-OH marketing. **The underlying hypothesis has been substantially refuted** — morphine's respiratory depression persists in β-arrestin-2 knockouts, and other biased agonists still depress respiration. Direct refutation for 7-OH: Hill et al. 2022 found naloxone-reversible respiratory depression comparable to or exceeding morphine. **[A]**

Assume a classic opioid risk profile, including additive respiratory depression with benzodiazepines, alcohol, and gabapentinoids.

### 1.4 The half-life asymmetry — the single most important fact for the taper engine

| Condition | Half-life |
|---|---|
| Single dose | **~1.7–5.7 h** (commonly ~4–6 h) |
| Repeated/steady-state dosing | **>20 h, up to ~24.7 h** |

Everything downstream follows from this pair:

- The ~4–6 h figure explains the **3–5 h redose clock** and why interdose withdrawal is a daily lived experience rather than an abstract endpoint.
- The >20 h steady-state figure explains why **full withdrawal onset lags the last dose by 8–12 h**, not 3 h, and why the peak sits at 36–72 h.
- **Critically: a taper cut can feel completely fine for ~48 hours and then bite on day three.** This is the mechanism behind the most common self-taper failure — the user reads two good days as permission to accelerate, cuts again, and the two cuts land simultaneously.

**Design rule, non-negotiable:** the app must never offer an early step-down on short-window good data. Step prompts are gated on a minimum hold duration *and* a flat-or-falling withdrawal trend.

### 1.5 Downstream metabolite
7-OH rearranges in human plasma to **mitragynine pseudoindoxyl (MP)** — reported ~31× more potent than 7-OH — with an in-plasma conversion half-life of ~99 min. MP is itself now marketed and is covered by the DEA scheduling action. Relevant mainly as a reminder that "how much opioid am I actually on" is fuzzier than the label suggests.

### 1.6 Product accuracy — a first-class app concern
This is the largest obstacle to accurate self-tracking, and it deserves a data field rather than a footnote.

- LC-MS analysis of commercial 7-OH products found measured content consistently **below** label claim, ranging **32% to 81%** of stated amount. **[A]**
- Tablet-to-tablet variability *within a single product*: **RSD 10–17%**. **[A]**
- Vendor certificates of analysis are themselves questionable — kratom matrices contain isomers producing near-identical mass spectra, creating real false-identification risk. **[A]**
- Over 93% of these products are marketed as "kratom"; ~69% use child-appealing flavors. **[A]**

**Consequences:**
1. A logged "5 mg" is realistically 1.6–4 mg of actual 7-OH, ±10–17% between tablets from the same bottle.
2. **A brand or lot switch is a hidden dose change in both directions.** Moving from an under-dosed brand to an accurate one at the same nominal mg can be a real 2–3× jump; the reverse produces unexplained withdrawal that reads as taper failure and triggers an unnecessary hold or reversal.
3. Therefore: **log brand + lot with every dose, flag any change prominently, and treat the entire taper as percent-of-your-own-baseline rather than trusting absolute milligrams.** Staying on a single brand — ideally a single bulk purchase — for the duration is worth more than any dosing precision gained elsewhere.

### 1.7 Regulatory status (live, verify before the app asserts anything)
FDA recommended scheduling July 2025; DEA issued Notices of Intent 1 Jul 2026, published in the Federal Register 6 Jul 2026, with earliest effect 5 Aug 2026. Scope: 7-OH above a threshold of >0.05% or >1 mg per article — which captures essentially all commercial tablets, gummies, and shots. Mitragynine and ordinary kratom leaf are **not** scheduled.

**Design consequence:** supply may vanish mid-taper and force an unplanned cold turkey. The app should nudge the user to establish a fallback — leaf supply, a buprenorphine-capable telehealth prescriber, naloxone on hand — *before* the plan reaches its middle, rather than discovering the gap at the worst moment.

---

## 2. Taper science

### 2.1 Guideline rates
The HHS *Guide for Clinicians on the Appropriate Dosage Reduction or Discontinuation of Long-Term Opioid Analgesics* (2019) is the most quotable source. **[C — guideline consensus]**

- Common tapers: **5–20% every 4 weeks.**
- "Slower tapers (e.g., **10% per month or slower**) are often better tolerated... especially following opioid use for more than a year."
- Faster option: **10% of the original dose per week until 30% of original is reached, then 10% of the remaining dose weekly.**
- "**At times, tapers might have to be paused and restarted again when the patient is ready.**"
- "Tapers may be considered successful **as long as the patient is making progress, however slowly**."
- "Once the smallest available dose is reached, **the interval between doses can be extended.** Opioids may be stopped when taken less often than once a day."

Note that the "faster taper" has a built-in denominator switch at the 30% mark — from *original* dose to *remaining* dose. That switch is the guideline quietly acknowledging the hyperbolic problem below.

### 2.2 Hyperbolic tapering — why the last third is genuinely harder

The most useful recent literature for this app. Dose-to-receptor-occupancy is governed by the law of mass action and is therefore **hyperbolic, not linear** — diminishing incremental effect at higher doses, which means *increasing* incremental effect at lower ones. **[B — pharmacological modeling with supporting cohort data]**

Worked example from the buprenorphine literature:

| Reduction | Drop in MOR occupancy |
|---|---|
| 16 mg → 12 mg | ~5.4 percentage points |
| 4 mg → 0 mg | ~53.9 percentage points |

**Ten times larger for the same 4 mg cut.** This is the quantitative answer to "why is the end so much harder" — it is not weakness or fear of the void, it is that at low doses you are on the steep part of the occupancy curve.

**Therefore: reduce a percentage of the *current* dose, never of the original.** Recommended rate **1–10% of most recent dose every 1–2 weeks**, symptom-titrated.

Community 7-OH taper logs corroborate this from the failure side: schedules cutting 10% of the *original* dose every two days visibly collapse around day four, typically with a rebound above the starting dose.

### 2.3 Duration predicts success, and the intuition is backwards
**[B]** From the same review:
- Tapers at **<5% weekly** had significantly better outcomes than faster ones.
- Tapers of **12–52 weeks were ~3.6× more likely to succeed** than short tapers.
- Tapers **>52 weeks were ~6.7× more likely** to succeed.

The instinct that a fast taper is the decisive, serious one is exactly wrong. Slow is the version that finishes. The app should state this plainly, because a user staring at a six-month plan needs to know that the six-month plan is the *high-probability* one.

### 2.4 What this means numerically for this user

At 15 mg he is at ~33% of a 45 mg baseline — right at the boundary where the guideline switches denominators and the occupancy curve steepens.

| Phase | Dose band | Rate |
|---|---|---|
| Stabilize | 15 mg | 1–2 weeks, **zero reduction**, log only |
| Upper | 15 → 10 mg | ~7–8% of current, every 10 days (~5 steps) |
| Lower | 10 → 5 mg | ~5% of current, every 10–14 days (~14 steps) |
| Endgame | below ~5 mg | **extend the interval** rather than cutting further; stop when dosing is less than daily |

**Realistic finish: around February 2027**, roughly 26 more steps. **The app must accept arbitrary-precision dose entry, not tablet counts.**

**Jump-off:** community practice suggests jumping from ~5–10 mg/day equivalent, with 24–72 h of real but attenuated withdrawal after. No published number exists. **[C/D]**

### 2.4.1 Precision: move to the powder now, not below 7 mg

The original plan assumed a switch to weighing near the end of the taper. Given §0.1, that is backwards — **the switch should happen first, because without it there is no measurable baseline to taper from.** He already owns 95%+ purity powder and a scale, which is everything required.

Weighing 5 mg directly is the wrong approach: a 1 mg-resolution scale gives ±20% at that mass, and inexpensive 0.1 mg scales are unreliable below ~20 mg regardless of their stated readability — displayed precision is not accuracy. **Volumetric dosing solves this by moving the weighing step into the scale's reliable range.**

The principle (standard practice in clinical benzodiazepine and antidepressant microtapering, and the same technique the kratom community uses):

- Weigh a mass large enough to be accurate — at ~100 mg, a 1 mg scale is ±1% rather than ±20%.
- Dissolve into a known volume to get a round concentration. 100 mg of 95% powder ≈ 95 mg 7-OH; into 95 mL of liquid that is **1.0 mg/mL**.
- Dose by oral syringe. A 5 mg dose is 5.0 mL. A 0.25 mg step is 0.25 mL — trivially measurable on a 10 mL syringe, and far finer than any step the taper will need.

Two practical notes. **7-OH is poorly water-soluble as a freebase**, so plain water yields a suspension that stratifies between doses — the exact erratic dosing being eliminated. Acidifying (citric acid, or lemon juice) converts it to a more soluble salt and gives a true solution. And **alkaloid solutions degrade**, so batches should be small (about a week), refrigerated, and light-protected.

**The crossover carries a real asymmetric risk, and this is the most important safety point in the document.** Switching from tablets of unknown potency to verified 95%+ powder is itself a brand switch of the most dangerous kind (§1.6). If his tablets have been running at, say, 50% of label, then a nominal 5 mg of powder-derived dose is roughly **double** what he has actually been taking. The two error directions are not equivalent:

- **Underestimating** produces withdrawal — unpleasant, not dangerous.
- **Overestimating** produces respiratory depression — dangerous.

**Therefore start deliberately low and titrate up.** The app should run the crossover as a structured protocol: replace one dose slot at a time (morning first), hold the other two on tablets, wait 3–4 days for the >20 h accumulation to settle before judging (§1.4), and only then convert the next slot. Withdrawal during crossover means titrate up slightly; it does not mean the protocol failed. Naloxone should be in the house before the first converted dose.

Once all three slots are on solution, the "baseline" is finally a real number, and percentage steps start meaning something.

### 2.5 Stabilization first
You cannot taper from a moving baseline — if intake varies day to day, "10% reduction" is noise and any withdrawal signal is uninterpretable. Protocol: **1–2 weeks of pure logging, zero reduction.** Compute total daily mg using the **median, not the mean** (protects against one heavy day inflating baseline). Map the interdose interval distribution. Only then set D₀ and begin.

This phase costs nothing and delivers the baseline, the withdrawal-signal reference, and the data for a personalized trigger model.

### 2.6 Holds
Holds are protocol, not failure. HHS: "Significant opioid withdrawal symptoms may indicate a need to pause or slow the taper rate." Suggested automatic hold triggers:
- SOWS rise of ≥8 points over the pre-step baseline sustained ≥3 days
- Sleep under 4 h for 3 consecutive nights
- Any off-plan dose
- Self-COWS analogue ≥13

**Hold, don't reverse.** Universal advice across clinical and community sources: if a cut produces unmanageable symptoms, hold 1–2 weeks and resume — stepping back up restarts the ratchet.

---

## 3. Withdrawal, and how the app measures it

### 3.1 Timeline

| Phase | Timing |
|---|---|
| Onset | **8–12 h** after last dose (some sources 4–6 h) |
| Peak | **24–72 h** (commonly ~48 h) |
| Acute resolution | **days 4–10** |
| Protracted | **weeks to months** — dysphoria, insomnia, irritability, anhedonia, craving |

Symptom profile is standard short-acting-opioid withdrawal — myalgia and deep bone pain (very prominent in 7-OH reports), restless legs, GI upset, thermoregulatory swings, rhinorrhea, lacrimation, yawning, tachycardia, tremor, severe insomnia — plus the disproportionate **depression and anhedonia** noted in §1.2.

Severity sits roughly at prescription-opioid level: physical symptoms at or slightly below heroin/fentanyl, mood symptoms reported as worse or longer-lasting. Generally "uncomfortable but not medically dangerous," with the real risk being dehydration from vomiting and diarrhea — but one published case at 700–800 mg/day escalated to hallucinations, disorientation, and respiratory compromise requiring intubation. That is the far tail; it establishes the syndrome can be medically serious at high dose.

**On PAWS:** the phenomenon is real and guideline-acknowledged (HHS: "some symptoms can take weeks to months to resolve"). The specific circulated timelines — "peaks at 2–12 weeks, improves over 6–9 months, up to two years" — trace to treatment-center marketing, not primary literature. **Do not display specific PAWS durations as fact.** Do warn that protracted symptoms ebb and flow rather than decline monotonically, because an unexpected bad day after a good week is a classic relapse trigger.

### 3.2 SOWS — the instrument the app should administer

Handelsman et al. 1987. Self-administered, 16 items, each rated 0–4 (not at all / a little / moderately / quite a bit / extremely). Total 0–64. Under 10 minutes; in an app with tap targets, under 60 seconds.

Instruction, verbatim: *"Please score each of the 16 items below according to how you feel right now."*

1. I feel anxious
2. I feel like yawning
3. I am perspiring
4. My eyes are teary
5. My nose is running
6. I have goosebumps
7. I am shaking
8. I have hot flushes
9. I have cold flushes
10. My bones and muscles ache
11. I feel restless
12. I feel nauseous
13. I feel like vomiting
14. My muscles twitch
15. I have stomach cramps
16. I feel like using now

**Implementation notes:**
- SOWS has no validated absolute cut-points — it is designed for **within-person change over time**, which is exactly what a taper needs. Score against the user's own pre-step baseline, never an absolute threshold.
- **Item 16 is a craving item.** Score 1–15 as a somatic/affective withdrawal subscore and track item 16 separately, so a craving spike doesn't masquerade as physiological withdrawal and trigger a spurious hold.
- **Administer at trough — immediately pre-dose, same slot every day.** Post-dose SOWS is flat and uninformative. For this user the natural slot is right before the evening dose.

COWS (clinician-administered, 0–48, with published severity bands: 5–12 mild, 13–24 moderate, 25–36 moderately severe, >36 severe) is not cleanly self-administrable, but pulse, gooseflesh, and pupil size are all self-observable with a phone. A self-COWS variant is reasonable as a secondary escalation trigger **if labeled as unvalidated**.

### 3.3 Comfort measures

| Measure | Evidence | Note |
|---|---|---|
| α2-agonists (clonidine, lofexidine) | **[A]** Cochrane, 25 RCTs, 1,668 participants — both beat placebo, roughly equivalent to tapered methadone over ~10 days | Prescription. Lofexidine has fewer hypotensive events and is preferred outpatient. |
| Exercise | **[A]** Meta-analysis, 16 trials / 1,032 participants — reduced cravings across light, moderate, and high intensity | Best-supported non-drug measure; good in-app urge alternative |
| Loperamide | **[A]** at label dose for diarrhea | **Hard-cap at 8 mg/day OTC with the FDA cardiac warning displayed.** High doses cause QT prolongation, torsades, cardiac arrest; 10 deaths in FDA's 1976–2015 review, many in people self-treating opioid withdrawal. This population *is* the at-risk group. |
| Hydration/electrolytes | **[C]** | The main medical risk of unsupervised withdrawal |
| Sleep hygiene / CBT-I | **[C]** for withdrawal, **[A]** for insomnia generally | Insomnia is among the most persistent symptoms |
| OTC supplements (magnesium, melatonin, L-theanine, etc.) | **[D]** | No efficacy evidence; consistently reported as helpful from day 3–4 onward. Note 5-HTP must not be combined with SSRIs/SNRIs/tramadol. |

### 3.4 Escalation triggers — when the app should say "this needs a person"

- **Suicidal ideation or serious psychological distress.** Highest priority. HHS names suicidal thoughts as an explicit risk of rapid taper.
- Inability to keep fluids down, or signs of dehydration.
- Any cardiac symptom while using loperamide — palpitations, syncope, near-syncope. Emergency.
- Respiratory depression or unresponsiveness — emergency services, naloxone, and **expect possible re-sedation** because 7-OH's half-life far exceeds naloxone's.
- **Repeated inability to progress despite genuine effort, or escalating use.** This is a specific, treatable finding, not a character verdict — and buprenorphine has a far better evidence base than self-tapering. First published 7-OH-specific case (ASAM 2026): patient on 30–50 mg/day for 2 years, low-dose induction, discharged day 5 on Suboxone 4/1 mg TID with minimal withdrawal and maintained craving control at follow-up. Accessible via telehealth in most US states.
- Concurrent benzodiazepine or alcohol dependence — those withdrawals can be fatal; opioid withdrawal alone generally is not.

### 3.5 The tolerance-loss warning
HHS: *"Strongly caution that it takes as little as a week to lose tolerance and that there is a risk of overdose if they return to their original dose."*

For this user that is concrete and urgent: **a relapse at his old 40–50 mg is the classic overdose scenario, and it gets more dangerous the better the taper goes.** Naloxone on hand is cheap insurance and does reverse 7-OH. This warning must appear at every lapse and after every dosing gap — not buried in a settings page.

### 3.6 One uncomfortable population-level finding
In 21,515 tapering events among 19,377 patients, tapering was associated with **adjusted IRR 1.57 for overdose/withdrawal events** and **1.52 for mental health crisis** versus the pre-taper period, persisting 12–24 months (Agnoli et al., *JAMA* 2021). These cohorts are largely *involuntary*, clinician-initiated tapers in chronic pain, so they don't generalize cleanly to a voluntary self-directed taper. But they are the strongest available argument for going slow, keeping naloxone available, monitoring mood as a first-class signal, and treating the tapering period as elevated-risk rather than automatically safer.

**Depression specifically predicts taper dropout** (HHS). Mood tracking is not a wellness garnish here; it is a taper-relevant instrument.

---

## 4. Behavioral science that earns its place

### 4.1 Hyperkatifeia — the concept the app is built around
From Greek *katifeia*, dejection. Koob's term for the intensified negative emotional state of withdrawal: dysphoria, anxiety, irritability, sleep disturbance, emotional pain, anhedonia. **[B]**

Mechanism: blunted dopamine and endogenous opioid tone in ventral striatum (nothing else feels good) plus recruitment of brain stress systems in the extended amygdala — CRF, dynorphin, norepinephrine, glucocorticoids.

**Why it matters:** hyperkatifeia converts drug use from positive reinforcement (feeling good) to **negative reinforcement** (escaping feeling bad). Late-stage use is relief-seeking, not pleasure-seeking. Every piece of app copy should assume the user is trying to stop feeling bad, not trying to get high — because that is almost certainly true.

The plain-language framing worth putting in the app: *withdrawal is not the drug leaving; it is your own compensatory machinery running unopposed. It resolves as that machinery winds down — over weeks, not hours.*

### 4.2 The abstinence violation effect — the most important concept for lapse handling
Marlatt & Gordon. **[B]** The AVE is the set of cognitive and affective reactions to a lapse that make full relapse more likely: the lapse is read as evidence of personal failure, producing guilt, shame, and hopelessness.

The critical finding: **the progression from lapse to relapse is not inevitable — attributions determine it.** The spiral is driven by internal/stable/global attribution ("I'm someone who can't do this") rather than external/unstable/specific ("I was exhausted and hadn't eaten"), and by the perception that there is no intermediate state between a lapse and total relapse.

**Direct design consequences:**
- **Never display a counter that resets to zero.** A reset-to-zero counter is a literal instantiation of the all-or-nothing cognition that drives the AVE. This is not a stylistic preference — it is the single clearest place where a common app pattern actively causes harm, and users of streak-based sobriety apps say so in reviews unprompted.
- Show **cumulative and averaged** metrics instead: percent below baseline, total mg avoided, 7-day rolling average, on-plan days out of the last 30 (rolling, self-healing).
- **Pre-commit a lapse plan while calm**, in the user's own words, and replay it at the moment.
- **The post-lapse screen is the highest-stakes surface in the app.** It should name the AVE, restate that a lapse is not a relapse, prompt for situational attribution, show the cumulative progress that still stands, give one concrete next action (the next scheduled dose time), and carry the tolerance-loss warning.
- Language: "off-plan dose," "lapse," "data point." Never "failure," "slip-up," "relapse," "clean/dirty."

### 4.3 Contingency management — the strongest lever available, and hard to use here
**[A]** Bolívar et al., *JAMA Psychiatry* 2021: 74 reports, 10,444 participants. Effect sizes at end of treatment: **illicit opioid abstinence d = 0.58**, medication adherence d = 0.75, pooled abstinence d = 0.58. This is the best-supported psychosocial intervention in addiction, full stop.

CM works when reinforcement is contingent on **objectively verified** behavior, immediate, escalating with consecutive successes, and frequent.

**The problem: a solo self-report app cannot verify abstinence.** Options in descending strength: involve a real person who holds a deposit or delivers the reward; deposit contracts with the user's own money; **verifiable proxy behaviors** (timestamped schedule adherence, daily SOWS completion, exercise via phone sensors, sleep); self-administered escalating rewards (weakest, non-zero).

**Reinforce process, not outcome.** Rewarding "logged every dose" and "held the step" is more robust than rewarding "used zero" — the latter creates an incentive to stop logging after a lapse, which is precisely the wrong behavior.

### 4.4 Self-monitoring: honest expectations
**[A/B]** Gass et al. 2021, 41 studies / 126 analyses. Among moderate-to-strong quality studies: **helpful 29%, no effect 63%, detrimental 8%.** Digital delivery outperformed paper; longer monitoring was more effective.

And a randomized experiment on measurement reactivity found daily diary monitoring reduced drinking in **week 1 only**, dissipating by week 2 — with the interpretation that reactivity appears for behaviors that *fluctuate*, not for highly consistent daily ones.

**Consistent multi-daily 7-OH dosing is exactly the profile where reactivity is weakest. Logging alone should not be expected to reduce use, and the app should not promise that it will.** Its value here is instrumental: establishing baseline, detecting withdrawal signal, driving the taper algorithm, enabling CM verification, and building a personalized trigger model. Frame it that way.

The counterexample that *does* work: structured app-delivered CBT + contingency management. reSET pivotal trial, n = 399: abstinence **40.3% vs 17.6%**. The differentiator is content plus contingency, not tracking.

### 4.5 Things the internet says that are not true
The app's credibility depends on getting these right, and being visibly honest about weak evidence buys trust on the things that *are* solid.

- **"Cravings peak at 3 minutes and pass in 20."** No primary source. Circulates through treatment-center and self-help content. **[D]** Better: *"Urges rise, peak, and fall on their own. Yours may last minutes or longer."* Then measure the user's own urges from start/end timestamps and quote their real average back to them — honest, personalized, and more persuasive than a made-up number.
- **HALT (Hungry/Angry/Lonely/Tired).** A 2025 review traces it to AA folk wisdom with no identifiable origin and notes "scant research in the scientific literature." **[D]** The underlying constructs (nutrition, fatigue, emotional regulation, relationships) are well-researched; the four-item taxonomy is arbitrary. Useful as a pause-and-check mnemonic, not as an instrument. A trigger model built from the user's own logged data — time of day, sleep debt, hours since last dose, stress rating — beats a generic acronym, and the app is uniquely positioned to build one.
- **Specific PAWS timelines.** Marketing, not literature. **[D]**
- **Streak counters as motivation.** Actively harmful here — see §4.2.

### 4.6 What does work, briefly
- **CBT [A]:** g = 0.58–0.67 vs minimal intervention, but **null vs contingency management and null vs motivational interviewing.** The app doesn't need to pick a school; it needs to deliver *some* structured skills-based intervention consistently. The shared active ingredients are self-monitoring, trigger analysis, coping rehearsal, and planned responses to high-risk situations.
- **Mindfulness-Oriented Recovery Enhancement [A]:** *JAMA Internal Medicine* 2022, n = 250 — at 9 months, **45.0% no longer misusing opioids vs 24.4%** of controls. Notably includes *savoring* — deliberately amplifying natural rewards to counteract the anhedonia of the reward-deficit state. That component is under-used in apps and aims squarely at hyperkatifeia.
- **Motivational interviewing [A]:** small-to-moderate (d ≈ 0.2–0.4) at a fraction of the contact time. For app copy the operational rules are: evoke rather than install reasons, never argue against ambivalence, affirm process, roll with resistance, and **support autonomy explicitly** — "this is your call" is an active ingredient, not politeness.
- **Collaborative, patient-controlled tapering [B]:** HHS is unusually direct — "Tapering is more likely to be successful when patients collaborate in the taper." Darnall's patient-centered taper pilot achieved a median 288 → 150 MEDD (48% reduction) with no increase in pain, using a deliberately gentle first month (≤5%, twice) before increasing pace. **That slow-start structure is worth copying** — it front-loads confidence and lets the user learn the withdrawal-monitoring loop while pharmacological stakes are lowest.
- **Frequent follow-up [B]:** "Successful tapering studies have used at least weekly follow-up." An app delivers daily contact at zero marginal cost. This is its single largest structural advantage over usual care.

---

## 5. UX decisions

Full survey in the UX research pass; the decisions that survive:

1. **Primary metric: 7-day average dose vs baseline (% reduction).** Never a consecutive-day streak. Cumulative counters (total mg avoided, money not spent) may exist because they only go up.
2. **Home screen is today's budget.** One large number — remaining mg — with the day's dose slots beneath it. Modeled on Sunnyside's daily target and the descending-allowance pattern from caffeine-reduction apps.
3. **Percentage-based taper steps with a first-class one-tap Hold.** The plan shifts silently; the finish date is a soft moving estimate. Never "you are X days behind."
4. **Logging is one tap** from widget, watch, or Control Center, pre-filled with the usual amount, with editable timestamp and retrospective backfill. The two extra fields that earn their place are **why** (scheduled / withdrawal / craving — the ratio is the earliest signal a step is too steep) and **batch** (§1.6).
5. **Off-plan doses log identically to any other dose.** Neutral confirmation copy, amber rather than red, optional trigger note. "Logged. 18 mg today, plan was 15."
6. **Weekly planning ritual, weekly review** — precommitment when motivation is high, following Sunnyside's Sunday pattern.
7. **Gain-framed stats only.** Gain-framing beats loss-framing for cessation behaviors in RCT evidence.
8. **Local-only, no account, Face ID lock, discreet name and icon, neutral notification text.** This is table stakes in this niche — the two existing kratom-taper apps both lead their store listings with it. Lock-screen copy never mentions doses or drug names.
9. **Tone:** matter-of-fact and warm, zero moralizing, person-first language, one large number per screen.
10. **Content restraint.** Reframe's most common complaint is that its content volume is overwhelming; Bearable's is that logging takes ten minutes. For a single-user personal tool, the tracker plus a small toolkit is the whole product.

---

## 6. Platform architecture

Full detail in the platform research pass. The paid developer account removes the free-tier constraints (7-day provisioning expiry, no time-sensitive notifications, no CloudKit), so everything below is available.

**Logging surfaces, in order of friction:**
- **Interactive Home Screen widget** — `Button(intent:)` executes an AppIntent *in the widget extension's process*; the app never opens. This is the primary phone logger. Debounce it: rapid repeat taps can fire the intent multiple times.
- **Control Center control** (`ControlWidget`, iOS 18+) — one implementation lands in Control Center, the Lock Screen bottom slots, *and* the Action Button. Lowest-friction path on iPhone: press the Action Button, dose logged, phone never unlocked.
- **Watch Smart Stack widget** — supports interactive `Button(intent:)`. **Watch-face complications do not** — they are tap-to-launch only, so the complication shows time-since-last-dose and opens the watch app to a one-tap log screen.
- **Watch app** with `.handGestureShortcut(.primaryAction)` — Double Tap logs a dose one-handed without touching the screen.
- **App Shortcuts / Siri** via `AppShortcutsProvider` (no SiriKit entitlement needed). Name the intent something neutral — Siri phrases are spoken aloud.

**Live Activities:** `Activity.request(pushType: nil)` — locally updated, no push required. The key trick is that `Text(timerInterval:)` and `ProgressView(timerInterval:)` are **rendered and advanced by the system continuously**, so a countdown to the next dose window runs for hours with zero app wakeups. Constraint: activities cap at ~8 hours (~12 on iOS 18+), so rather than one all-day activity, **each dose log starts a fresh countdown to the next window and ends it there** — which fits a 3-dose schedule exactly. Watch Smart Stack mirroring is automatic; adopt `.supplementalActivityFamilies([.small])` for a proper watch layout.

**AlarmKit (iOS 26)** is worth considering for step-down days and window boundaries — alarms fire through Silent mode and Focus. Use sparingly; an alarm is aggressive.

**HealthKit:**
- **Source of truth stays app-local** (SwiftData in an App Group). HealthKit reads can block on authorization and the schema is too rigid for dose + reason + batch + craving context.
- **Mirror where types exist:** `HKStateOfMind` (iOS 18) for mood and craving logging — valence, labels, associations, charted free in Apple's Health app; `.mindfulSession` for breathing interventions; `HKMedicationDoseEvent` (iOS 26) for dose events, though the medication itself must be created by the user in the Health app first.
- **Read:** sleep stages, resting HR, HRV — all withdrawal correlates worth charting against taper steps, and all corroborating evidence for the SOWS scores he didn't have to enter.
- **Live heart rate needs an `HKWorkoutSession`.** Passive background HR delivery is batched every 8–15 minutes, so **passive craving detection is not achievable** — but live HR as biofeedback during a user-initiated intervention is fully supported and worth building.
- There is **no API to launch Apple's Breathe session.** Build the breathing animation with haptic pacing inside a `WKExtendedRuntimeSession` of type mindfulness (up to 1 hour), then write a `.mindfulSession` sample so it counts as Mindful Minutes.

**Data:** SwiftData with `ModelConfiguration(groupContainer:)` shared across app, widget, and control extensions. App Groups do **not** span devices — iPhone↔Watch uses `WCSession` (`updateApplicationContext` for state snapshots, `transferUserInfo` for guaranteed dose-event delivery), with both sides keeping local stores and reconciling by UUID. Swift Charts for the taper curve, with `RuleMark` for the planned line over actual daily mg.

**Targets:** App + WidgetExtension (widgets, Live Activity, Controls, intents) + WatchApp + WatchWidgetExtension. App Intents live in a shared package so every surface invokes identical logging logic.

**Floor:** iOS 18 / watchOS 11 minimum; adopt iOS 26 additions (AlarmKit, Medications API, RelevanceKit) behind `if #available`.

---

## 7. The build, in order

0. **The crossover protocol (§2.4.1)** — before or alongside the first code. Everything the taper engine does is meaningless while the baseline swings 80% by bottle. The app can support this immediately with nothing more than a log and a checklist.
1. **Data model + logging.** Intake entity (substance, mg, timestamp, reason, brand, lot, preparation, on/off-plan), free-text check-in, inferred + measured SOWS entries, taper plan and step. Arbitrary-precision mg. This is the foundation everything else reads.
2. **Today screen + log sheet.** One-tap logging with the pre-filled usual dose; free-text box always reachable.
3. **Copilot tier 1** — on-device parsing of free text into structured symptoms, with SOWS calibration passes.
4. **Taper engine.** Percent-of-current steps, hold logic, symptom-gated step-down prompts, the 48-hour delayed-feedback guard.
5. **Plan + Trends screens.** The descending staircase with actual doses plotted; all metrics cumulative or averaged.
6. **Widgets, Control Center control, Live Activity.**
7. **Watch app** — one-button logger, complication, Smart Stack widget.
8. **Adjunct logging + n-of-1 correlations**, including cannabis escalation detection.
9. **Copilot tier 2** — opt-in cloud synthesis, weekly review, taper re-planning.
10. **Toolkit** — wave timer with personal urge-duration stats, breathing with haptics, his own implementation intentions, comfort-measure reference with the loperamide cap, and the "just in case" safety card.
11. **Post-lapse screen.** Small, and the most carefully written thing in the app.

---

## 8. The copilot

The requested centerpiece: an ally that monitors continuously and gives feedback, accepting free-text input at dose time or any other time — "I should be able to just open the app and describe how I feel whenever" — which then feeds the adaptive taper model.

### 8.1 The core idea: free text replaces the SOWS form

The SOWS (§3.2) is the right instrument and the wrong interface. Sixteen items every evening is exactly the logging burden that kills self-monitoring adherence — Bearable's most common complaint is that logging takes ten minutes, and mHealth usage distributions are brutally skewed toward users who quit after a day.

**So: he describes how he feels in his own words, and the model scores it onto the 16 SOWS items.** "Legs won't stop, didn't sleep, sweating through my shirt" maps to elevated items 11 (restless), 3 (perspiring), and a sleep flag, producing a SOWS-equivalent score with zero taps. The validated instrument's structure is preserved; the chore is not.

**Calibration matters, or this drifts.** Periodically — at the start of each step, and any time the inferred score jumps — administer the real 16-item SOWS and compare it against what the model inferred from that day's free text. That comparison is stored, and systematic bias gets corrected. Without this the model is an unvalidated vibe detector wearing a validated instrument's name.

Free text also carries what a form cannot: causal attribution ("this started after I skipped lunch"), context, and the user's own language for his states — which the copilot should mirror back rather than translating into clinical vocabulary.

### 8.2 What the copilot is responsible for

1. **Parse** free text (typed or spoken) into structured symptoms with severities.
2. **Correlate** against the dose log, position in the current step, adjunct log, and passive HealthKit signals.
3. **Recommend** — hold or proceed, which adjunct addresses the symptom in front of him, and what to do right now at 2am.
4. **Gate the taper engine.** The adaptive model decides step timing; the 48-hour delayed-feedback guard (§1.4) is enforced here and cannot be overridden by a good-feeling day.
5. **Notice things he wouldn't.** This is the part that justifies the word "ally" — pattern observations across weeks: *"your three worst nights all followed days where the 5pm dose slipped past 6:30."*

### 8.3 Continuous monitoring without nagging

"Continuously monitoring" comes from passive signal, not from prompting him repeatedly. Available without any interaction:

- **Dose-timing drift** — slots creeping earlier is interdose withdrawal compressing, the single best early warning that a step is too steep.
- **Sleep** (HealthKit, written by the watch) — a genuine withdrawal marker and among the most persistent symptoms.
- **Resting HR and HRV** — autonomic arousal; elevated resting HR corroborates a self-reported bad day with data he didn't enter.
- **Respiratory rate during sleep.**
- **Activity/step drop** — a plausible proxy for the anhedonia and fatigue of hyperkatifeia (§4.1).
- **Reason-for-dose ratio** — scheduled vs withdrawal-driven vs craving-driven, from the log sheet.

The copilot speaks up on signal, not on schedule. Notification discipline from §6 still binds: two a day maximum.

### 8.4 Architecture — three tiers, privacy-first

| Tier | Model | Runs | Job |
|---|---|---|---|
| 1 | Apple Foundation Models, on-device | Every check-in, real-time, offline | Free-text → structured symptoms, the 2am response, triage |
| 2 | `PrivateCloudComputeLanguageModel` (iOS 27) | Nightly / weekly | Deeper synthesis under Apple's stateless privacy guarantees. Free, no key. |
| 3 | Claude API, opt-in | Occasional | Heaviest reasoning — months of cross-signal correlation, taper re-planning |

Apple's Private Cloud Compute tier is the better default for the middle job than a third-party API, given the data. iOS 27's `LanguageModel` protocol means all three share one `LanguageModelSession` and `@Generable` code path, so tiering is a model swap rather than three integrations. Tier 3 is opt-in per run, shows exactly what will be sent, and the app stays fully functional with it off forever.

### 8.4.1 The guardrail problem — the biggest technical risk in the project

Apple's on-device model applies safety filtering to **both prompt and output**, and a violation throws `GenerationError.guardrailViolation`, which is **non-recoverable** — no retry will fix it. Separately the model can simply refuse, which surfaces as a different error, so both paths need handling.

Known false-positive-prone categories reported by developers include death, violence, and personal journal entries about difficult topics. There are field reports that **health and medical terminology trips refusals even in permissive mode**, and at least one report that the iOS 27 model became *more* sensitive to medical terms than 26.x. An app whose every prompt contains opioid dose data is squarely in the blast radius.

Mitigations, in order of effectiveness:

1. **Use `SystemLanguageModel(guardrails: .permissiveContentTransformations)`** (iOS 26.1+). It relaxes filtering specifically for text-to-text *transformation* of user-provided content — which is exactly what symptom parsing is. It does not relax freeform generation.
2. **Frame every prompt as transformation, never as advice.** "Extract structured data from the user's own log entry below" rather than "what should this person do about their withdrawal."
3. **Prefer guided generation into constrained enums.** Constrained decoding cannot emit disallowed free text, and empirically reduces refusals. Symptom categories should be a `@Generable enum`, not free prose.
4. **Keep substance names in structured fields and tool outputs**, not in generated prose.
5. **Always ship a deterministic non-AI fallback** — a keyword parser plus manual entry. A refusal must degrade to "couldn't analyze that entry," never to lost data. **The AI layer is additive; logging must never depend on it.**
6. **Store refusals** as a first-class status so the app knows which entries were never analyzed and can retry them after an OS update.

This needs prototyping against real prompts on-device before committing to the design. It is the one item that could force tier 1 to the cloud.

### 8.4.2 Other implementation constraints worth knowing now

- **Context is small:** 4,096 tokens total on iOS 26 (instructions + transcript + prompt + response), 8,192 on iOS 27. Batch a day's records into one request; do not send raw history.
- **The model hallucinates numbers.** Never ask it to compute averages, deltas, or dose math — compute in Swift and pass results in as formatted strings, or expose them via a `Tool` it quotes verbatim. Given that this app is entirely about numbers, this constraint shapes everything: **the model interprets, Swift calculates.**
- **Property order in `@Generable` structs matters** — fields generate in declaration order, so extraction fields go first and summary/derived fields last, which gives the summary the earlier fields as context.
- **Include a verbatim `evidence` field** in every parse so any inferred severity is auditable against the user's own words, and make the parse user-editable. Corrections are also ground truth for calibrating against real SOWS runs (§8.1).
- **Voice check-ins** use `SpeechTranscriber`/`SpeechAnalyzer` (iOS 26) — fully on-device, no session length limit. Gotcha: **no custom-vocabulary API**, so brand names like "7-OHMIT" and "Astral Glitter" will mis-transcribe. Needs a fuzzy-match correction pass against a local dictionary of his products before parsing.
- **Nightly synthesis** uses `BGProcessingTask` with `requiresExternalPower`. It is discretionary and not guaranteed to run, and background Foundation Models calls are rate-limited — so budget a handful of calls per pass and run a catch-up synthesis on next foreground launch when the nightly one didn't fire.
- **Persist assessments append-only** with `promptVersion`, `schemaVersion`, `modelProvider`, `osVersion`, and `status`. On-device model identity tracks the OS, so outputs are not reproducible across updates; versioning is what makes stale assessments findable and re-runnable.

### 8.5 Tone

The copilot inherits §4.6's motivational-interviewing rules: evoke rather than install, never argue against ambivalence, affirm process over outcome, roll with resistance, and support autonomy explicitly. A user who wants to hold or reverse a step is giving information, not being non-compliant.

It must also be honest when it doesn't know. The adjunct evidence base is thin (§9); the app's credibility depends on saying "this is widely used and barely studied" rather than manufacturing confidence.

---

## 9. Adjuncts

**The honest headline: taper rate is the intervention, and everything in this section is a rounding error next to it.** Of everything reviewed, only **zinc** has a positive RCT in opioid withdrawal specifically (small, unreplicated), **CBD** has a good RCT for craving and anxiety at doses retail products don't reach, **dronabinol/THC** has two small RCTs with a narrow therapeutic window, and **clonidine/lofexidine** have Cochrane-level support. Everything else is extrapolation from insomnia and anxiety populations. That's not a reason to skip the cheap safe ones — it's a reason not to let them carry the plan.

### 9.1 Structural decisions

- **One intake log, several substances.** 7-OH is the substance with a taper plan attached; adjuncts share the stream so the copilot can correlate them against symptoms.
- **N-of-1 comparison is the payoff.** With enough logged nights the app answers "how bad was the RLS on magnesium nights versus without" for *him*. Given how thin the supplement literature is, his own data is genuinely better evidence than anything the app could cite.
- **Supplement label accuracy is a real confounder.** One analysis of 31 US melatonin products found actual content from **−83% to +478% of label**. Same problem class as §1.6. USP/NSF-verified products only, and the app should log brand here too.

### 9.2 Cannabis — the highest-risk item in the plan, and it needs saying plainly

Cannabis was requested, so this gets detail rather than a dismissal. **THC and CBD are different interventions and should not be lumped together.**

**What the evidence actually shows.** A 2022 systematic review (11 studies, n=5,330) found two RCTs, both of **dronabinol** (oral synthetic THC), not plant cannabis. One showed reduced withdrawal symptoms versus placebo; the other showed a non-significant improvement in naltrexone-induction success. Harms were dose-limiting and real — heart rate 107–112 bpm on active dose against 84 at baseline, with the 40 mg arm discontinued for persistent tachycardia and anxiety. Nine observational studies split four positive, one negative, four null. The review's own conclusion is a **"narrow therapeutic window"**: THC is biphasic, anxiolytic low and anxiogenic higher. The AHRQ evidence review issues a **strong recommendation against cannabinoids for OUD management**.

**CBD is the better-evidenced half.** Hurd et al. (*Am J Psychiatry* 2019, n=42) found 400–800 mg oral CBD significantly reduced cue-induced craving and anxiety, with reduced cortisol and heart rate and effects persisting about a week after the last dose. No intoxication, no abuse-liability signal. **The catch is dose:** retail 25–50 mg products are an order of magnitude below what was tested, and there is no evidence a 25 mg gummy reproduces that result. High-dose CBD also inhibits CYP3A4 — see the loperamide interaction in §9.6.

**Nightly THC for sleep across a six-month taper is the single worst choice available here**, and the mechanism is specific rather than moralistic:

1. THC suppresses REM and does not produce normal sleep architecture.
2. **Tolerance to the sedative effect develops faster than tolerance to REM suppression** — within weeks the sleep benefit fades while the architectural distortion persists, so the dose climbs.
3. On stopping, **REM rebound** produces shortened REM latency, vivid disturbing dreams, longer sleep onset, more waking, and reduced total sleep — days 1–7, with cannabis withdrawal peaking days 2–6 and running 2–3+ weeks in heavy users.
4. That syndrome is clinically indistinguishable from opioid withdrawal, arriving exactly when he's trying to declare the taper finished.

Add the base rates: roughly **1 in 3 dependence risk among weekly-or-more-frequent users**, and **17.8% of daily users report cannabinoid hyperemesis symptoms** — intractable vomiting indistinguishable from withdrawal nausea, whose only reliable treatment is cessation. The realistic failure mode is completing the opioid taper and immediately facing a second one.

**Route matters.** Inhaled peaks in 6–10 minutes and lasts 2–4 hours with ~20% conversion to 11-OH-THC. Edibles onset in 30 min–2 h, last 6–10 hours, and undergo ~90–100% first-pass conversion to 11-OH-THC, which is **4–10× more potent centrally**. Delayed feedback drives stacking. **Inhaled is titratable and appropriate for acute spikes; edibles are the wrong tool for a taper.**

**Design position:** cannabis stays in the app, logged with route, quantity, and THC/CBD split, and gets **the same escalation detection 7-OH gets**. If frequency or quantity trends up — particularly if nightly-for-sleep emerges — the copilot says so directly. An ally that only watches the substance you asked it to watch isn't much of an ally.

### 9.3 Corrections to the current stack

- **Melatonin: 5–10 mg is too high.** Dose-response meta-analysis (26 RCTs) peaks around **4 mg** with benefit falling off above; physiologic dosing work favors **0.5–1 mg**, and higher doses mainly add next-day grogginess and vivid dreams. **Timing is the stronger lever than dose** — ~2–3 h before target bedtime beat the usual 30-minutes-before practice. Protocol: 0.5–1 mg, 2–3 h before lights-out, titrating toward 3 mg only if no effect after a week. Also note melatonin is chronobiotic, not hypnotic — it re-anchors a wrecked schedule, it does not sedate through acute withdrawal. No tolerance or rebound; safe for months.
- **Vitamin C: drop the high-dose protocol.** The gram-level claim rests on a single unreplicated 2000 study (n=40, all-male, unblinded, non-equivalent control). Against that: 2 g/day raises urinary oxalate ~22%, and there are documented cases of **oxalate nephropathy and reversible renal failure** from high-dose ascorbate — with diarrhea and dehydration listed as aggravators, which is to say withdrawal conditions specifically amplify the risk. Gram doses are also an osmotic laxative, worsening the diarrhea. **250–500 mg/day with food and good hydration**, as ordinary nutrition, no withdrawal expectation. Avoid entirely with any stone or renal history.
- **Magnesium: glycinate, 200–400 mg elemental, evening.** Glycinate is the right form — highest dose tolerable without a laxative effect, which matters when the taper already causes loose stools. Avoid oxide (~4% bioavailable, strong laxative); threonate isn't worth the premium. Evidence for RLS and sleep is weak-to-moderate and strongest in people actually deficient. Renal caution: magnesium is renally cleared, so impaired kidney function is a contraindication.

### 9.4 Worth adding — better evidence-to-risk than most of the above

- **Oral rehydration solution.** Highest-yield, lowest-risk item in the entire report and routinely neglected. Withdrawal produces diarrhea, sweating, vomiting, and rhinorrhea simultaneously; the resulting depletion causes weakness, cramps, palpitations, and dizziness that get misread as "worse withdrawal." A glucose–sodium co-transport formulation beats water or sports drinks. It also reduces clonidine hypotension risk and NSAID/vitamin C renal risk.
- **Zinc 15–30 mg/day with food.** The only item here with a **positive RCT in opioid withdrawal specifically** — 30 mg/day for a month reduced COWS scores, depression scores, and inflammatory markers. Small and single-center, but it's the best direct evidence available. Cap at 30 mg and consider time-limiting to the hardest phase: **>40 mg/day chronically induces copper deficiency.**
- **Topical menthol / methyl salicylate.** RCT-supported for muscle pain, negligible systemic load, unlimited daily use, non-sedating. Ideal for withdrawal myalgia and restless legs. Underrated; should be first-line.
- **Glycine 3 g before bed.** Improves subjective sleep quality and onset latency **without altering sleep architecture** — the direct contrast with THC. Small trials, very safe, cheap, synergizes with magnesium glycinate.
- **L-theanine 200 mg.** Mild edge-off agent for anxiety and sleep latency; note RCTs in diagnosed GAD failed on primary anxiety endpoints, so calibrate expectations downward. No dependence.
- **NSAIDs and acetaminophen PRN** for myalgia — standard supportive care. Not continuously for months: daily NSAIDs bring GI erosion (on an already-irritated gut), renal risk (compounded by dehydration), and hypertension. Acetaminophen hard max 3,000 mg/day.
- **Check ferritin.** Low ferritin is a treatable cause of RLS and is easy to miss — a blood test is worth more here than any supplement guess.

### 9.5 Avoid

- **Ashwagandha** — documented idiosyncratic liver injury including a case requiring transplant, plus a reported discontinuation syndrome. A modest anxiolytic effect that theanine covers more safely isn't worth adding a DILI signal to a stack that already carries hepatic load.
- **5-HTP, L-tryptophan, St John's wort** — serotonergic; see §9.6.
- **Nightly antihistamines** (diphenhydramine, doxylamine) — tolerance to sedation within days to weeks, anticholinergic burden associated with dementia risk at chronic exposure, and anticholinergic restlessness that can aggravate RLS. Occasional rescue only, ≤2 nights/week.
- **Gabapentinoids** — not requested, but frequently suggested. ~70% increased odds of respiratory depression with opioids and 49% higher opioid-related mortality in co-prescribed cohorts. There is always residual 7-OH on board during a taper.
- **Alcohol** — additive respiratory depression, worse sleep architecture, worse GI, worse mood, worse hydration. No safe role.

### 9.6 Interaction warnings the app must carry

- **One sedating agent at a time**, lowest effective dose, and never a second one because the first isn't working. 7-OH depresses respiration at >3× morphine potency, and levels swing through the day.
- **Serotonin risk is real with 7-OH** — it interacts with serotonergic receptors and inhibits CYP2D6, 3A4, 2C9, 1A2. Multiple published serotonin-syndrome case reports with kratom plus serotonergic agents. **Dextromethorphan is the sleeper hazard** — it's in a great many OTC cough and cold products, it's serotonergic, and it's CYP2D6-metabolized, so 7-OH raises its levels. The app should flag "DM" products explicitly. Tramadol and tapentadol are worst-case. Disclosure to a prescriber matters, but **never stop a prescribed antidepressant mid-taper** — that's its own disaster.
- **Loperamide ≤8 mg/day**, and never with P-glycoprotein or CYP3A4 inhibitors — quinine (including tonic water in quantity), clarithromycin, azole antifungals, verapamil, cimetidine, grapefruit. **Specific to this plan: high-dose CBD inhibits CYP3A4, so CBD plus loperamide requires strict label dosing.** Any online advice about "making Imodium work better" is describing deliberate P-gp inhibition to force CNS penetration — the mechanism behind the reported cardiac arrests.
- **Do not stack QT-prolonging agents** with loperamide (hydroxyzine, ondansetron, some antibiotics and antidepressants).
- **B6 above 100 mg/day for months** causes sensory peripheral neuropathy that will be misread as a withdrawal symptom. Many high-potency B-complexes contain 50–100 mg.

### 9.7 Clonidine — the reserved option, and get it before it's needed

Central alpha-2 agonist; suppresses the locus-coeruleus noradrenergic hyperactivity that drives the autonomic half of withdrawal — sweating, chills, lacrimation, rhinorrhea, tachycardia, hypertension, GI hypermotility, restlessness. Cochrane-supported. It does **not** treat craving, insomnia, or myalgia.

- **Threshold for "extremely bad":** sustained **COWS ≥13** with prominent autonomic features, or symptoms severe enough that a hold can't be maintained and relapse is imminent.
- **Typical dosing is prescriber-directed** — commonly 0.1–0.3 mg three or four times daily, with blood pressure checked before each dose and held for SBP <90 or symptomatic hypotension.
- **It must be tapered off, not stopped** — abrupt discontinuation causes rebound hypertension. This means it can't be used continuously for weeks and then dropped, which is a real trap for an "emergency rescue" framing.
- **Get it prescribed in advance.** Clonidine is a non-controlled antihypertensive, so telehealth prescribing is straightforward and carries none of the DEA constraints that apply to buprenorphine. Having it on hand with monitoring instructions and a written taper-off plan beats trying to obtain it mid-crisis. The same visit can cover ferritin, 25-OH vitamin D, and whether a non-controlled hypnotic is appropriate.
- Lofexidine is equally effective with less hypotension but typically costs $100–300+ against a few dollars for generic clonidine, and is labeled for 14 days. Generic clonidine is the pragmatic choice for an occasional rescue role.

### 9.8 Escalation thresholds, written down in advance

COWS >24 · inability to hold fluids for 24 h · suicidal ideation · confusion, agitation, or psychosis → **in-person medical care, not another supplement.** The published 7-OH case literature includes a presentation that reached intubation and ICU care.

---

## 10. Answered — user decisions on record

- **Products:** five in rotation (§0). Halved on the score line. Astral Glitter 95%+ powder and a scale available. Tablets cannot be weighed for content due to fillers.
- **No anchor dose.** All three slots equal at ~8am / ~12pm / ~5pm. The general advice to protect the morning dose longest does not apply to a flat schedule; step reductions come off all three proportionally.
- **Buprenorphine: not now.** Escalation copy should not push it. §3.4's other escalation triggers (suicidality, dehydration, cardiac symptoms on loperamide, respiratory depression) remain.
- **Ally: yes**, as an in-app AI copilot rather than a human contact. Note this does not satisfy the contingency-management verification requirement (§4.3), which needs an external party — CM stays limited to verifiable process behaviors.
- **App name: Nopiate.** Discreet-naming guidance from §5.8 applies to the *display* name and icon on the home screen; worth deciding separately whether the springboard label should be something more neutral.
