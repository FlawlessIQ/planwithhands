# Plan With Hands — Website Scaffold

## Run locally
cd website/marketing
npm install
npm run dev

## Build
npm run build

## Deploy (Firebase Hosting)
firebase hosting:sites:create hands-web
firebase target:apply hosting hands-web hands-web

Add this to firebase.json:
{
  "hosting": [
    {
      "target": "hands-web",
      "public": "website/marketing/dist",
      "ignore": ["**/.*","**/node_modules/**"],
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    }
  ]
}
