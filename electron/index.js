const electron = require('electron')
// Module to control application life.
const app = electron.app
// Module to create native browser window.
const BrowserWindow = electron.BrowserWindow

const path = require('path')
const url = require('url')

const remoteMain = require('@electron/remote/main')
remoteMain.initialize();

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow

function createWindow() {

    mainWindow = new BrowserWindow({
        width: 1280, height: 720,
        webPreferences: {
            nodeIntegration: true, contextIsolation: false, backgroundThrottling: false, enableRemoteModule: true,
        }
    })

    mainWindow.setMenuBarVisibility(false);
    remoteMain.enable(mainWindow.webContents);

    mainWindow.loadURL(url.format({
        pathname: path.join(__dirname, 'index.html'),
        protocol: 'file:',
        slashes: true
    }))

    mainWindow.loadURL(url.format({
        pathname: path.join(__dirname, 'index.html'),
        protocol: 'file:',
        slashes: true
    }));
}

app.on('ready', createWindow)

app.on('window-all-closed', function () {

    app.quit()

})

