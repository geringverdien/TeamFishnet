import * as vscode from "vscode";
import WebSocket from "ws";


// constants
const baseUrl: string = "ws://127.0.0.1:24892";
const timeout: number = 30 * 1000; // ms
const statusTimeout: number = 3 * 1000; // ms
const defaultText: string = "$(triangle-right) Finapse Execute :3";
const defaultCommand: string = "extension.finapse-xecute";

// websocket init
let wsClient: WebSocket | null = null;
let isAlive: boolean;
let runItem: vscode.StatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left);
runItem.command = defaultCommand;
runItem.tooltip = "Execute GDScript - Made with <3 by TeamFishnet 🐟🥅";
runItem.text = defaultText;

// Connect to WebSocket
function connectWebSocket(): Promise<WebSocket> {
    return new Promise((resolve, reject) => {
        console.log("Starting connection attempt...");
        const ws = new WebSocket(baseUrl);
        
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

function sendAndWaitForResponse(ws: WebSocket, message: string): Promise<string> {
    return new Promise((resolve, reject) => {
        const timeoutId = setTimeout(() => {
            reject(new Error("Websocket Timeout"));
        }, timeout);

        const messageHandler = (data: WebSocket.Data) => {
            clearTimeout(timeoutId);
            ws.removeListener('message', messageHandler);
            resolve(data.toString());
        };

        ws.send(message);
		ws.on('message', messageHandler);
    });
}

// misc
function resetRunItem(): void {
    runItem.text = defaultText;
    runItem.command = defaultCommand;
    runItem.show();
}

// execution function
export function activate({ subscriptions }: vscode.ExtensionContext): void {
    console.log(`finapse execution plugin loaded :3`);

    isAlive = true;
    runItem.show();
    resetRunItem();

    let disposable: vscode.Disposable;
    disposable = vscode.commands.registerCommand("extension.finapse-xecute", async () => {
        const content: string = vscode.window.activeTextEditor?.document.getText() || "";
        if (content.trim() === "") {
            return;
        }

        runItem.command = "";
        runItem.text = "Loading...";


		try {
			if (!wsClient || wsClient.readyState !== WebSocket.OPEN) {
				wsClient = await connectWebSocket();
			}
		
			//console.log("About to send IS_READY");
			const IS_READY = await sendAndWaitForResponse(wsClient, "IS_READY");
			//console.log("Received response for IS_READY:", IS_READY);

            if (IS_READY !== "TRUE") {
                let currentAttach: string = "";
                let attach: string;

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
            } else {
                vscode.window.showErrorMessage("Script errord during runtime");
            }

        } catch (e) {
            const err: string = (e as Error).message;

            console.log(err);
            if (err.includes("Websocket") && err.includes("connection failed")) {
                return vscode.window.showErrorMessage("Error occurred while executing",
                    "Couldn't connect to finapse!");
            }

            resetRunItem();
            return vscode.window.showErrorMessage("Error occurred :(", err);
        }

        resetRunItem();
        //vscode.window.showInformationMessage("Script executed!");
    });

    subscriptions.push(disposable);
}

export function deactivate(): void {
    console.log(`finapse execution plugin shutting down...`);

    isAlive = false;
    runItem.dispose();

    if (wsClient && wsClient.readyState === WebSocket.OPEN) {
        wsClient.close();
    }
}