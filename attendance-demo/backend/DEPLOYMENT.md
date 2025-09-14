# Smart Attendance API Deployment Guide

## Files Ready for Deployment
- ✅ requirements.txt (all dependencies included)
- ✅ Procfile (for Railway/Heroku)
- ✅ railway.json (Railway configuration)
- ✅ main.py (configured for cloud deployment)

## Deploy to Railway (Free)

1. **Sign up**: Go to [railway.app](https://railway.app)
2. **New Project** → "Deploy from GitHub repo"
3. **Connect your GitHub account**
4. **Upload this backend folder to GitHub**
5. **Select the repository in Railway**
6. **Deploy automatically**

## Deploy to Render (Free Alternative)

1. **Sign up**: Go to [render.com](https://render.com)
2. **New** → "Web Service"
3. **Connect GitHub repository**
4. **Settings**:
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

## After Deployment

1. **Get your public URL** (e.g., `https://smart-attendance-api.railway.app`)
2. **Update Flutter app** with the new URL in `lib/main.dart`
3. **Test the API** at `https://your-url.com/docs`

## Environment Variables (Optional)
- `JWT_SECRET_KEY`: Set a secure secret key for production
- `PORT`: Automatically set by the platform

Your API will be publicly accessible once deployed!
