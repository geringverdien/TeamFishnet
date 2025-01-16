"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const ws_1 = __importDefault(require("ws"));
// constants
const baseUrl = "ws://127.0.0.1:24892";
const timeout = 30 * 1000; // ms
const statusTimeout = 3 * 1000; // ms
const defaultText = "$(triangle-right) Finapse Execute :3";
const defaultCommand = "extension.finapse-xecute";
// websocket init
let wsClient = null;
let isAlive;
let runItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left);
runItem.command = defaultCommand;
runItem.tooltip = "Execute GDScript - Made with <3 by TeamFishnet 🐟🥅";
runItem.text = defaultText;
// Connect to WebSocket
function connectWebSocket() {
    return new Promise((resolve, reject) => {
        console.log("Starting connection attempt...");
        const ws = new ws_1.default(baseUrl);
        ws.on('open', () => {
            console.log("WebSocket connection opened");
            resolve(ws);
        });
        //
        //ws.on('error', (error) => {
        //    console.log("WebSocket error:", error);
        //    reject(error);
        //});
        //
        //ws.on('close', (code, reason) => {
        //    console.log("WebSocket closed:", code, reason);
        //});
        //
        //ws.on('message', (data) => {
        //    console.log("Raw message received:", data.toString());
        //});
    });
}
function sendAndWaitForResponse(ws, message) {
    return new Promise((resolve, reject) => {
        const timeoutId = setTimeout(() => {
            reject(new Error("Websocket Timeout"));
        }, timeout);
        const messageHandler = (data) => {
            clearTimeout(timeoutId);
            ws.removeListener('message', messageHandler);
            resolve(data.toString());
        };
        ws.send(message);
        ws.on('message', messageHandler);
    });
}
// misc
function resetRunItem() {
    runItem.text = defaultText;
    runItem.command = defaultCommand;
    runItem.show();
}
// execution function
function activate({ subscriptions }) {
    console.log(`finapse execution plugin loaded :3`);
    isAlive = true;
    runItem.show();
    resetRunItem();
    let disposable;
    disposable = vscode.commands.registerCommand("extension.finapse-xecute", async () => {
        const content = vscode.window.activeTextEditor?.document.getText() || "";
        if (content.trim() === "") {
            return;
        }
        runItem.command = "";
        runItem.text = "Loading...";
        try {
            if (!wsClient || wsClient.readyState !== ws_1.default.OPEN) {
                wsClient = await connectWebSocket();
            }
            //console.log("About to send IS_READY");
            const IS_READY = await sendAndWaitForResponse(wsClient, "IS_READY");
            //console.log("Received response for IS_READY:", IS_READY);
            if (IS_READY !== "TRUE") {
                let currentAttach = "";
                let attach;
                await sendAndWaitForResponse(wsClient, "ATTACH");
                while (isAlive) {
                    attach = await sendAndWaitForResponse(wsClient, "");
                    //console.log(`FINAPSE ATTACH ${attach}`);
                    if (attach === "READY" || attach === "ALREADY_ATTACHED" || attach === "REATTACH_READY") {
                        runItem.text = `FINAPSE STATUS: READY`;
                        break;
                    }
                    if (currentAttach !== attach) {
                        runItem.text = `$(watch) FINAPSE STATUS: ${attach}`;
                        currentAttach = attach;
                    }
                }
            }
            const scriptResp = await sendAndWaitForResponse(wsClient, content);
            if (scriptResp === "OK") {
                vscode.window.showInformationMessage("Script Executed");
            }
            else {
                vscode.window.showErrorMessage("Script errord during runtime");
            }
        }
        catch (e) {
            const err = e.message;
            console.log(err);
            if (err.includes("Websocket") && err.includes("connection failed")) {
                return vscode.window.showErrorMessage("Error occurred while executing", "Couldn't connect to finapse!");
            }
            resetRunItem();
            return vscode.window.showErrorMessage("Error occurred :(", err);
        }
        resetRunItem();
        //vscode.window.showInformationMessage("Script executed!");
    });
    subscriptions.push(disposable);
}
function deactivate() {
    console.log(`finapse execution plugin shutting down...`);
    isAlive = false;
    runItem.dispose();
    if (wsClient && wsClient.readyState === ws_1.default.OPEN) {
        wsClient.close();
    }
}
//# sourceMappingURL=extension.js.map