@echo off
echo ==============================================
echo [1/3] Running flutter clean and pub get...
echo ==============================================
call flutter clean
call flutter pub get

echo ==============================================
echo [2/3] Building Flutter Web (Release)...
echo ==============================================
call flutter build web --release

echo ==============================================
echo [3/3] Deploying to Firebase Hosting...
echo ==============================================
call firebase deploy --only hosting

echo ==============================================
echo Deployment finished!
echo ==============================================
pause

