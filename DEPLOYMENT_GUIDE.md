# 🚀 Streamlit Deployment Guide

## Quick Deploy to Streamlit Cloud (Recommended)

### Step 1: Upload to GitHub
1. Go to [github.com](https://github.com) and create a new repository
2. Name it something like `foundation-model-digital-twin`
3. Upload these files:
   - `streamlit_app.py`
   - `requirements.txt`  
   - `README.md`
   - `.streamlit/config.toml` (create `.streamlit` folder first)

### Step 2: Deploy on Streamlit Cloud
1. Go to [share.streamlit.io](https://share.streamlit.io)
2. Sign in with your GitHub account
3. Click **"New app"**
4. Select your repository
5. Set:
   - **Main file path**: `streamlit_app.py`
   - **Python version**: 3.9-3.11 (recommended)
6. Click **"Deploy"**

### Step 3: Your App is Live! 🎉
- Your app will be available at: `https://your-username-your-repo-name.streamlit.app`
- It will automatically update when you push changes to GitHub

---

## Alternative: Local Development

If you want to run locally first:

```bash
# Install Python packages
pip install streamlit pandas numpy plotly scikit-learn seaborn matplotlib

# Run the app
cd /path/to/FoundationModel
streamlit run streamlit_app.py
```

---

## 📱 What Your Deployed App Will Include

### 🏠 **Main Dashboard**
- Dataset overview with interactive charts
- Model performance metrics
- Patient cohort statistics

### 🤖 **Digital Twin Generator**  
- Patient selector dropdown
- Real-time prediction generation
- Personalized treatment recommendations
- Risk stratification (High/Medium/Low)

### 📊 **Interactive Visualizations**
- Survival distribution by cancer subtype
- Model performance scatter plots
- Feature importance analysis
- Resistance probability distributions

### 🏥 **Clinical Applications Section**
- Personalized medicine applications
- Research use cases  
- Clinical decision support features

---

## 🎯 **Demo Features**

Your deployed app will demonstrate:

1. **Foundation Model Architecture**
   - Multi-modal data integration (clinical + genomic)
   - Machine learning model training and validation
   - Real-time prediction capabilities

2. **Digital Twin System**
   - Patient-specific computational models
   - Personalized survival prediction (months)
   - Platinum resistance probability (0-1 scale)
   - Treatment recommendations based on AI predictions

3. **Clinical Validation**  
   - Actual vs predicted outcomes comparison
   - Model accuracy metrics
   - Feature importance for interpretability

---

## 📧 **Sharing Your App**

Once deployed, you can:
- Share the URL with your lab members
- Present it during your lab meeting
- Use it for demos with clinical collaborators
- Include it in research presentations

The app is **publicly accessible** but contains only simulated demo data, so it's safe to share widely.

---

## 🔧 **Troubleshooting**

**If deployment fails:**
1. Check that all files are uploaded to GitHub
2. Ensure `requirements.txt` has correct package versions
3. Make sure `streamlit_app.py` is in the root directory
4. Check Streamlit Cloud build logs for specific errors

**Common issues:**
- **Package conflicts**: The `requirements.txt` uses tested versions
- **Memory limits**: The demo is optimized for Streamlit Cloud's resources
- **Loading time**: First load may take 30-60 seconds to generate data

---

## 🎓 **For Your Presentation**

Your deployed app is perfect for:
- **Live demonstration** during lab meeting
- **Interactive exploration** with Prof. Karen Chan and team
- **Showcasing clinical applications** to medical collaborators
- **Demonstrating technical capabilities** to potential partners

The app runs entirely in the browser and requires no local installation for viewers!

---

**Ready to deploy?** Just follow Steps 1-2 above and your foundation model demo will be live in minutes! 🚀