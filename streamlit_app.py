import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, roc_auc_score
import seaborn as sns
import matplotlib.pyplot as plt
from datetime import datetime

# Configure page
st.set_page_config(
    page_title="Foundation Model + Digital Twin Demo",
    page_icon="🧬",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        color: #2E86AB;
        text-align: center;
        margin-bottom: 2rem;
    }
    .sub-header {
        font-size: 1.5rem;
        color: #A23B72;
        margin-top: 2rem;
        margin-bottom: 1rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        margin: 0.5rem 0;
    }
    .digital-twin-report {
        background-color: #e8f4fd;
        padding: 1.5rem;
        border-left: 5px solid #2E86AB;
        margin: 1rem 0;
        border-radius: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# Title and introduction
st.markdown('<h1 class="main-header">🧬 Foundation Model + Digital Twin</h1>', unsafe_allow_html=True)
st.markdown('<h2 style="text-align: center; color: #666;">Ovarian Cancer Survival & Platinum Resistance Prediction</h2>', unsafe_allow_html=True)

# Sidebar info
st.sidebar.markdown("## 📊 Demo Information")
st.sidebar.info("""
This demonstration showcases a foundation model + digital twin system for:
- **Survival Prediction**
- **Platinum Resistance Prediction**
- **Personalized Treatment Recommendations**

Built for Queen Mary Hospital ovarian cancer research.
""")

# Cache data generation function
@st.cache_data
def generate_demo_data(n_patients=200):
    """Generate realistic ovarian cancer dataset"""
    np.random.seed(42)
    
    # Patient metadata
    patients = pd.DataFrame({
        'id': [f"OV{i:03d}" for i in range(1, n_patients + 1)],
        'age': np.clip(np.random.normal(65, 12, n_patients).astype(int), 35, 85),
        'stage': np.random.choice(['IIIC', 'IV'], n_patients, p=[0.75, 0.25]),
        'subtype': np.random.choice(['HGSOC', 'CCOC', 'Other'], n_patients, p=[0.6, 0.25, 0.15]),
        'ca125': np.clip(np.random.lognormal(6, 1.2, n_patients).astype(int), 10, 50000),
        'brca_status': np.random.choice(['Wild-type', 'BRCA1/2_mut'], n_patients, p=[0.8, 0.2])
    })
    
    # Gene expression data (key cancer genes)
    gene_names = ['TP53', 'BRCA1', 'BRCA2', 'PIK3CA', 'PTEN', 'MYC', 'CCNE1', 'RB1', 'KRAS', 'AKT1'] + \
                 [f'GENE_{i:03d}' for i in range(11, 51)]
    
    gene_data = np.random.normal(5, 2, (len(gene_names), n_patients))
    
    # Add subtype-specific patterns
    hgsoc_mask = patients['subtype'] == 'HGSOC'
    ccoc_mask = patients['subtype'] == 'CCOC'
    
    # HGSOC signature (TP53 pathway)
    gene_data[:10, hgsoc_mask] += np.random.normal(1.5, 0.4, (10, hgsoc_mask.sum()))
    
    # CCOC signature (PI3K pathway)
    gene_data[10:20, ccoc_mask] += np.random.normal(1.8, 0.3, (10, ccoc_mask.sum()))
    
    gene_df = pd.DataFrame(gene_data.T, columns=gene_names, index=patients.index)
    
    # CNV data
    cnv_arms = ['1p', '1q', '3q', '6p', '8q', '11p', '17p', '17q', '19p', '20q', '22q']
    cnv_data = np.random.normal(0, 0.35, (len(cnv_arms), n_patients))
    
    # Add common OC CNV patterns
    cnv_data[2, hgsoc_mask] += np.random.normal(0.4, 0.2, hgsoc_mask.sum())  # 3q gain
    cnv_data[4, :] += np.random.normal(0.3, 0.25, n_patients)  # 8q gain (MYC)
    
    cnv_df = pd.DataFrame(cnv_data.T, columns=[f'cnv_{arm}' for arm in cnv_arms], index=patients.index)
    
    # Generate outcomes
    base_survival = np.where(patients['subtype'] == 'HGSOC', 28, 
                           np.where(patients['subtype'] == 'CCOC', 20, 24))
    
    # Multi-factor survival model
    age_effect = -0.25 * (patients['age'] - 65) / 12
    stage_effect = np.where(patients['stage'] == 'IV', -6, 0)
    brca_effect = np.where(patients['brca_status'] == 'BRCA1/2_mut', 8, 0)
    gene_effect = gene_df[['TP53', 'BRCA1', 'PTEN']].mean(axis=1) * 1.5
    cnv_effect = -cnv_df.abs().sum(axis=1) * 0.5
    
    survival_months = np.clip(
        base_survival + age_effect + stage_effect + brca_effect + gene_effect + cnv_effect + 
        np.random.normal(0, 4, n_patients), 2, 80
    )
    
    death_event = np.random.binomial(1, 1 / (1 + np.exp((survival_months - 24) / 10)))
    
    # Platinum resistance
    resist_base = np.where(patients['subtype'] == 'HGSOC', 0.30,
                          np.where(patients['subtype'] == 'CCOC', 0.70, 0.45))
    brca_resist_effect = np.where(patients['brca_status'] == 'BRCA1/2_mut', -0.35, 0)
    gene_resist_effect = np.tanh(gene_df['PIK3CA'] * 0.2 - gene_df['BRCA1'] * 0.1)
    
    resistance_prob = np.clip(
        resist_base + brca_resist_effect + gene_resist_effect + np.random.normal(0, 0.15, n_patients),
        0.05, 0.95
    )
    platinum_resistant = np.random.binomial(1, resistance_prob)
    
    # Combine all data
    patients['survival_months'] = np.round(survival_months, 1)
    patients['death_event'] = death_event
    patients['platinum_resistant'] = platinum_resistant
    patients['resistance_prob_true'] = np.round(resistance_prob, 3)
    
    # Feature matrix for ML
    clinical_features = pd.get_dummies(patients[['age', 'stage', 'subtype', 'brca_status']], drop_first=True)
    clinical_features['log_ca125'] = np.log10(patients['ca125'])
    
    features = pd.concat([clinical_features, gene_df.iloc[:, :20], cnv_df], axis=1)  # Use top 20 genes
    
    return patients, features

@st.cache_data  
def train_models(features, targets):
    """Train survival and resistance models"""
    X_train, X_test, y_surv_train, y_surv_test, y_resist_train, y_resist_test = train_test_split(
        features, targets['survival_months'], targets['platinum_resistant'], 
        test_size=0.3, random_state=42, stratify=targets['platinum_resistant']
    )
    
    # Survival model
    survival_model = RandomForestRegressor(n_estimators=100, random_state=42)
    survival_model.fit(X_train, y_surv_train)
    
    # Resistance model  
    resistance_model = RandomForestClassifier(n_estimators=100, random_state=42)
    resistance_model.fit(X_train, y_resist_train)
    
    # Evaluate
    surv_pred = survival_model.predict(X_test)
    resist_pred_prob = resistance_model.predict_proba(X_test)[:, 1]
    
    metrics = {
        'survival_mae': mean_absolute_error(y_surv_test, surv_pred),
        'survival_cor': np.corrcoef(surv_pred, y_surv_test)[0, 1],
        'resistance_auc': roc_auc_score(y_resist_test, resist_pred_prob)
    }
    
    return survival_model, resistance_model, metrics, (X_test, y_surv_test, y_resist_test)

# Generate or load data
if 'data_generated' not in st.session_state:
    with st.spinner('Generating demo data...'):
        patients, features = generate_demo_data()
        targets = patients[['survival_months', 'platinum_resistant']]
        st.session_state.patients = patients
        st.session_state.features = features
        st.session_state.targets = targets
        st.session_state.data_generated = True

patients = st.session_state.patients
features = st.session_state.features  
targets = st.session_state.targets

# Train models
if 'models_trained' not in st.session_state:
    with st.spinner('Training foundation models...'):
        survival_model, resistance_model, metrics, test_data = train_models(features, targets)
        st.session_state.survival_model = survival_model
        st.session_state.resistance_model = resistance_model
        st.session_state.metrics = metrics
        st.session_state.test_data = test_data
        st.session_state.models_trained = True

survival_model = st.session_state.survival_model
resistance_model = st.session_state.resistance_model
metrics = st.session_state.metrics

# Main dashboard
st.markdown('<h2 class="sub-header">📊 Foundation Model Performance</h2>', unsafe_allow_html=True)

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric("Total Patients", len(patients), help="Simulated ovarian cancer cohort")

with col2: 
    st.metric("Survival MAE", f"{metrics['survival_mae']:.1f} months", 
              help="Mean absolute error for survival prediction")

with col3:
    st.metric("Survival Correlation", f"{metrics['survival_cor']:.3f}",
              help="Correlation between predicted and actual survival")

with col4:
    st.metric("Resistance AUC", f"{metrics['resistance_auc']:.3f}",
              help="Area under curve for platinum resistance prediction")

# Dataset overview
st.markdown('<h2 class="sub-header">👥 Patient Cohort Overview</h2>', unsafe_allow_html=True)

col1, col2 = st.columns(2)

with col1:
    fig_subtype = px.pie(patients, names='subtype', title='Cancer Subtypes',
                        color_discrete_map={'HGSOC': '#2E86AB', 'CCOC': '#A23B72', 'Other': '#F18F01'})
    st.plotly_chart(fig_subtype, use_container_width=True)

with col2:
    fig_outcomes = px.histogram(patients, x='survival_months', color='subtype', 
                               title='Survival Distribution by Subtype', nbins=20)
    st.plotly_chart(fig_outcomes, use_container_width=True)

# Model performance visualization
st.markdown('<h2 class="sub-header">🎯 Model Performance</h2>', unsafe_allow_html=True)

X_test, y_surv_test, y_resist_test = st.session_state.test_data
surv_pred = survival_model.predict(X_test)
resist_pred_prob = resistance_model.predict_proba(X_test)[:, 1]

col1, col2 = st.columns(2)

with col1:
    fig_survival = go.Figure()
    fig_survival.add_trace(go.Scatter(x=y_surv_test, y=surv_pred, mode='markers',
                                     name='Predictions', opacity=0.6))
    fig_survival.add_trace(go.Scatter(x=[y_surv_test.min(), y_surv_test.max()],
                                     y=[y_surv_test.min(), y_surv_test.max()],
                                     mode='lines', name='Perfect Prediction', 
                                     line=dict(dash='dash', color='red')))
    fig_survival.update_layout(title='Survival Prediction Performance',
                              xaxis_title='Actual Survival (months)',
                              yaxis_title='Predicted Survival (months)')
    st.plotly_chart(fig_survival, use_container_width=True)

with col2:
    # ROC-like visualization for resistance
    resist_df = pd.DataFrame({
        'actual': y_resist_test,
        'predicted_prob': resist_pred_prob
    })
    fig_resist = px.box(resist_df, x='actual', y='predicted_prob',
                       title='Platinum Resistance Prediction',
                       labels={'actual': 'Actual Resistance', 'predicted_prob': 'Predicted Probability'})
    st.plotly_chart(fig_resist, use_container_width=True)

# Digital Twin Demo
st.markdown('<h2 class="sub-header">🤖 Digital Twin Demonstration</h2>', unsafe_allow_html=True)

# Patient selector
st.subheader("Select a Patient for Digital Twin Analysis")
selected_patient_id = st.selectbox("Choose Patient ID:", patients['id'].tolist())

if st.button("Generate Digital Twin Report", type="primary"):
    patient_idx = patients[patients['id'] == selected_patient_id].index[0]
    patient_info = patients.loc[patient_idx]
    patient_features = features.loc[patient_idx:patient_idx]
    
    # Make predictions
    pred_survival = survival_model.predict(patient_features)[0]
    pred_resistance_prob = resistance_model.predict_proba(patient_features)[0, 1]
    
    # Risk categorization
    if pred_survival < 15:
        risk_category = "🔴 HIGH RISK"
        risk_color = "red"
    elif pred_survival < 30:
        risk_category = "🟡 MEDIUM RISK" 
        risk_color = "orange"
    else:
        risk_category = "🟢 LOW RISK"
        risk_color = "green"
    
    # Treatment recommendation
    if pred_resistance_prob > 0.7:
        treatment_rec = "🚨 Alternative therapy recommended (high resistance risk)"
    elif pred_resistance_prob > 0.4:
        treatment_rec = "⚠️ Platinum therapy with close monitoring"
    else:
        treatment_rec = "✅ Standard platinum-based therapy"
    
    # Digital Twin Report
    st.markdown('<div class="digital-twin-report">', unsafe_allow_html=True)
    st.markdown(f"## 🤖 Digital Twin Report: {selected_patient_id}")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 👤 Patient Information")
        st.write(f"**Age:** {patient_info['age']} years")
        st.write(f"**Cancer Subtype:** {patient_info['subtype']}")
        st.write(f"**Stage:** {patient_info['stage']}")
        st.write(f"**BRCA Status:** {patient_info['brca_status']}")
        st.write(f"**CA-125:** {patient_info['ca125']:,}")
    
    with col2:
        st.markdown("### 🎯 AI Predictions")
        st.markdown(f"**Survival Prediction:** {pred_survival:.1f} months")
        st.markdown(f"**Risk Category:** <span style='color: {risk_color}'>{risk_category}</span>", 
                   unsafe_allow_html=True)
        st.write(f"**Resistance Probability:** {pred_resistance_prob:.3f}")
        st.write(f"**Treatment Recommendation:** {treatment_rec}")
    
    st.markdown("### 📊 Validation (Actual Outcomes)")
    col3, col4 = st.columns(2)
    
    with col3:
        actual_resistance = "RESISTANT" if patient_info['platinum_resistant'] == 1 else "SENSITIVE"
        st.write(f"**Actual Survival:** {patient_info['survival_months']} months")
        st.write(f"**Actual Resistance:** {actual_resistance}")
    
    with col4:
        # Prediction accuracy
        survival_error = abs(pred_survival - patient_info['survival_months'])
        st.write(f"**Survival Prediction Error:** {survival_error:.1f} months")
        
        resistance_correct = (pred_resistance_prob > 0.5) == (patient_info['platinum_resistant'] == 1)
        st.write(f"**Resistance Prediction:** {'✅ Correct' if resistance_correct else '❌ Incorrect'}")
    
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Feature importance for this prediction
    st.markdown("### 🔍 Key Predictive Features")
    
    feature_importance_df = pd.DataFrame({
        'feature': features.columns,
        'survival_importance': survival_model.feature_importances_,
        'resistance_importance': resistance_model.feature_importances_
    }).sort_values('survival_importance', ascending=False)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("**Top Survival Predictors:**")
        for i, row in feature_importance_df.head(5).iterrows():
            st.write(f"• {row['feature']}: {row['survival_importance']:.3f}")
    
    with col2:
        st.markdown("**Top Resistance Predictors:**")
        resistance_sorted = feature_importance_df.sort_values('resistance_importance', ascending=False)
        for i, row in resistance_sorted.head(5).iterrows():
            st.write(f"• {row['feature']}: {row['resistance_importance']:.3f}")

# Clinical Applications
st.markdown('<h2 class="sub-header">🏥 Clinical Applications</h2>', unsafe_allow_html=True)

col1, col2, col3 = st.columns(3)

with col1:
    st.markdown("""
    **🎯 Personalized Medicine**
    - Individual risk assessment
    - Treatment selection optimization
    - Prognosis estimation
    - Clinical trial matching
    """)

with col2:
    st.markdown("""
    **🔬 Research Applications**
    - Biomarker discovery
    - Patient stratification
    - Drug target identification
    - Resistance mechanisms
    """)

with col3:
    st.markdown("""
    **💊 Clinical Decision Support**
    - Treatment recommendations
    - Risk stratification
    - Monitoring protocols
    - Quality of life optimization
    """)

# Footer
st.markdown("---")
st.markdown("""
<div style='text-align: center; color: #666; margin-top: 2rem;'>
    <h3>🧬 Foundation Model + Digital Twin Demo</h3>
    <p>Built for Queen Mary Hospital Ovarian Cancer Research</p>
    <p>Developed by Claude AI Assistant | {}</p>
</div>
""".format(datetime.now().strftime("%Y-%m-%d")), unsafe_allow_html=True)