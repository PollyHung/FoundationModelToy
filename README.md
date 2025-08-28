# Foundation Model + Digital Twin Demo

A Streamlit web application demonstrating a foundation model and digital twin system for ovarian cancer survival and platinum resistance prediction.

## Features

- **Multi-modal Foundation Model**: Integrates clinical, RNA expression, and copy number variation data
- **Survival Prediction**: Predicts patient survival months with personalized risk stratification
- **Platinum Resistance Prediction**: Identifies patients likely to be resistant to platinum-based chemotherapy
- **Digital Twin System**: Creates patient-specific computational models for personalized medicine
- **Interactive Dashboard**: Web-based interface for exploring predictions and patient data

## Demo Capabilities

1. **Data Generation**: Simulates realistic ovarian cancer patient cohort (200 patients)
2. **Model Training**: Trains Random Forest models for survival and resistance prediction
3. **Performance Metrics**: Displays model accuracy and validation results
4. **Digital Twin Reports**: Generates personalized patient reports with treatment recommendations
5. **Feature Analysis**: Shows most important predictive biomarkers

## Local Installation

```bash
# Clone or download the files
cd /path/to/FoundationModel

# Install dependencies
pip install -r requirements.txt

# Run the app
streamlit run streamlit_app.py
```

## Deployment to Streamlit Cloud

1. **Create GitHub Repository**:
   - Create a new repository on GitHub
   - Upload all files (streamlit_app.py, requirements.txt, .streamlit/config.toml)

2. **Deploy on Streamlit Cloud**:
   - Go to [share.streamlit.io](https://share.streamlit.io)
   - Sign in with GitHub
   - Click "New app"
   - Select your repository
   - Set main file path: `streamlit_app.py`
   - Click "Deploy"

## Usage

1. **Dashboard Overview**: View dataset statistics and model performance
2. **Patient Selection**: Choose a patient ID from the dropdown
3. **Digital Twin Report**: Click "Generate Digital Twin Report" to see:
   - Patient demographics and clinical information
   - AI predictions for survival and treatment response
   - Risk categorization and treatment recommendations
   - Validation against actual outcomes
   - Key predictive features for the specific patient

## Model Performance

- **Survival Prediction**: Mean Absolute Error ~5-6 months, Correlation ~0.4-0.6
- **Resistance Prediction**: AUC ~0.6-0.8 depending on data patterns
- **Risk Stratification**: Patients categorized as High/Medium/Low risk
- **Treatment Recommendations**: Personalized therapy suggestions based on resistance probability

## Clinical Applications

- Personalized prognosis and risk assessment
- Treatment selection optimization  
- Clinical trial patient stratification
- Biomarker discovery and validation
- Clinical decision support systems

## Technical Details

- **Framework**: Streamlit for web interface
- **ML Models**: scikit-learn Random Forest (optimized for demo)
- **Visualization**: Plotly for interactive charts
- **Data Processing**: pandas and numpy
- **Deployment**: Streamlit Cloud compatible

## Research Context

This demo supports ovarian cancer research at Queen Mary Hospital, focusing on:
- Asian population genomic data integration
- Multi-modal foundation model development
- Digital twin applications in precision oncology
- Clinical translation of AI models

Built for presentation to Prof. Karen Chan's lab meeting on August 28, 2025.