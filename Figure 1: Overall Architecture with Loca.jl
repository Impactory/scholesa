Figure 1: Overall Architecture with Local Extraction
This diagram maps the learner and tutor interactions through the BOS, now explicitly including the local feature extraction path. 

graph LR
classDef default fill:#fff,stroke:#000,stroke-width:2px,color:#000;
L[Learner]
T[GenAI Tutor]
TO[Teacher Override]
subgraph BOS [Behavior Orchestration System]
direction TB
LFE[Local Feature Extraction]
FDM[Feature Detection Module]
SE[State Estimator - EKF]
ORC[Orchestrator - Control Policy]
MIA[MIA / MVL Integrity Gate]
LFE --> FDM
FDM --- SE
SE --- ORC
ORC --- MIA
end
L <-->|signals| LFE
L <-->|dialogue| T
TO --> BOS
BOS -->|constraints + prompts| T

Figure 2: State-Space Dynamics
This maps the mathematical state, control, and observation flow, including process and observation noise. 

graph LR
classDef default fill:#fff,stroke:#000,stroke-width:2px,color:#000;
X_T["Latent State x_t"]
U_T["Control u_t"]
X_T1["Latent State x_{t+1}"]
Y_T1["Observation y_{t+1}"]
W_T["Process Noise w_t"]
V_T["Observation Noise v_t"]
X_T -->|"f(x_t, u_t)"| X_T1
U_T --> X_T
W_T --> X_T1
X_T1 -->|"h(x_{t+1})"| Y_T1
V_T --> Y_T1

Figure 3: Extended Kalman Filter (with Missing-Observation Handling)
This diagram breaks down the EKF stages, updated to show the missing-observation handling step. 

graph TD
classDef default fill:#fff,stroke:#000,stroke-width:2px,color:#000;
IN["Inputs (Observation y_t)"]
MISS["Missing-Observation Handling


(Masking / Inflate R_t)"]
PRED["Prediction Phase


x_{t|t-1}, P_{t|t-1}"]
KG["Compute Kalman Gain


K_t"]
UPD["Measurement Update


x_{t|t}, P_{t|t}"]
OUT["Output: Updated Latent State"]
IN --> MISS
MISS --> KG
PRED --> KG
PRED --> UPD
KG --> UPD
UPD --> OUT

Figure 4: Metacognitive Verification Loop (MVL) & Corroboration
This illustrates the gating mechanism, now explicitly showing the corroboration constraint requirement. 

graph TD
classDef default fill:#fff,stroke:#000,stroke-width:2px,color:#000;
SIG["Interaction Signals"]
CORR["Corroboration Constraint


(e.g., >= 2 independent signals)"]
RISK["Detect Integrity Risk"]
MVL["Trigger MVL Gate


(Verify / Justify / Cite)"]
ACT["Evidence-Producing Learner Action"]
ACC["Accept / Advance GenAI Output"]
SIG --> CORR
CORR --> RISK
RISK -->|Risk > Threshold| MVL
MVL --> ACT
ACT -->|Update EKF State| ACC
RISK -->|Risk <= Threshold| ACC

Figure 5: Semantic Entropy Pipeline (Sampling vs. SEP)
This flowchart shows the dual paths for estimating hallucination risk, contrasting the heavy sampling method with the fast SEP method. 

graph TD
classDef default fill:#fff,stroke:#000,stroke-width:2px,color:#000;
GEN["GenAI Single Generation"]
SAMP["Sample M Candidate Outputs"]
CLUS["Cluster by Semantic Similarity"]
HSEM["Compute Cluster Entropy (H_sem)"]
INT["Extract Internal Signals


(e.g., hidden states, log-probs)"]
SEP["Semantic Entropy Probe (SEP)


r_t^{SEP} = g(z_t)"]
RISK["Integrity Risk Score"]
GEN --> SAMP
SAMP --> CLUS
CLUS --> HSEM
HSEM -->|High Latency| RISK
GEN --> INT
INT --> SEP
SEP -->|Low Latency / Compute| RISK

Figure 6: Federated Learning Architecture
This maps the privacy-by-design flow where raw data remains local and only updates are aggregated. 

graph TD
classDef default fill:#fff,stroke:#000,stroke-width:2px,color:#000;
RAW["Raw Interaction Data"]
DEV["Learner Device"]
EXT["On-Device Feature Extraction"]
LOC["Local Model Update (Compute Gradients)"]
NET["Transmit Parameter Updates


(NO RAW DATA)"]
AGG["Server / Cloud Aggregation


(e.g., Weighted Averaging)"]
GLO["Global Model Parameters"]
RAW --> DEV
DEV --> EXT
EXT --> LOC
LOC --> NET
NET --> AGG
AGG --> GLO
GLO --> LOC

Figure 7: Teacher Override, Blending, and Audit Logging
This illustrates the mathematical blending of interventions alongside the new rate limiting and audit logging features. 

graph TD
classDef default fill:#fff,stroke:#000,stroke-width:2px,color:#000;
ORC["Orchestrator Intervention u^{(O)}_t"]
TCH["Teacher Intervention u^{(T)}_t"]
RATE["Intervention Rate Limiting & Cooldowns"]
BLEND["Blending Mechanism


u_t = α_t u^{(T)}_t + (1-α_t) u^{(O)}_t"]
APP["Apply Blended Intervention"]
AUD["Audit Logging


(States, Risks, Overrides)"]
ORC --> RATE
RATE --> BLEND
TCH --> BLEND
BLEND --> APP
BLEND --> AUD