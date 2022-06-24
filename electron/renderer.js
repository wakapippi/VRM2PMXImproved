const server = require('ws').Server;
const fs = require('fs');
const EventEmitter = require('events');
var child = require('child_process').execFile;

const { dialog } = require('@electron/remote');
const { json } = require('express/lib/response');

const portMin = 5001;
const portMax = 8000;
let s;

let selectingBindingIndex = -1;

let usingPort = portMin;
while (usingPort < portMax) {

    try {
        s = new server({ port: usingPort });
        break;
    } catch {

        alert("port error")

    }
    usingPort++;
}



child("VRM2PMXImproved.exe", [usingPort.toString()], function (err, data) {

});

const convertMap = JSON.parse(fs.readFileSync("convert.json", { encoding: 'utf8' }));




let master;
let binding;


let unitySender;
let unityReceiver = new EventEmitter();

s.on('connection', function (ws) {

    ws.on('message', function (message) {

        let parsed = JSON.parse(message);
        if (parsed.name == "UnityInit") {
            document.querySelector('#step1').classList.remove("hidden-part");
            unitySender = ws;

            var obj = {
                name: "ConvertMap",
                payload: JSON.stringify(convertMap)
            }

            unitySender.send(JSON.stringify(obj));
            return;
        }

        unityReceiver.emit(parsed.name, parsed.payload);

    });

    ws.on('close', function () {
        //Unity閉じた
    });

});


async function sendToUnity() {

    if (document.querySelector('#avatar').files.length == 0 || document.querySelector('#avatar').files[0] == null) {
        return;
    }

    master = null;
    binding = null;
    selectingBindingIndex = -1;

    const file = document.querySelector('#avatar').files[0];
    const reader = new FileReader();

    let cb1;
    let cb2;

    let task1 = new Promise((suc, fail) => {
        cb1 = suc;
    });
    let task2 = new Promise((suc, fail) => {
        cb2 = suc;
    });


    reader.addEventListener("load", function () {
        var result = reader.result;
        var obj = {
            name: "VRMLoad",
            payload: result
        }

        unitySender.send(JSON.stringify(obj));

        unityReceiver.once("VRMStatus", (result) => {
            if (!result) {
                //Unity load Error
                f();
                return;
            }


            unityReceiver.once("BlendShapeMaster", (result) => {
                var received = JSON.parse(result);
                master = {}
                for (const iterator of received) {
                    master[iterator.relativePath] = iterator.names;
                }
                cb1();
            });
            unityReceiver.once("BlendShapeBinding", (result) => {
                binding = JSON.parse(result);
                cb2();
            });

        })

    }, false);

    if (file) {
        reader.readAsDataURL(file);
    }

    await Promise.all([task1, task2]);


    copyBlendShapeToProxyBind();

    sendBindingsToUnity();

    genetateBindingView();

    document.querySelector('#step2').classList.remove("hidden-part");
    document.querySelector('#extra').classList.remove("hidden-part");




}

function copyBlendShapeToProxyBind() {
    //masterからクリップ名を照合する
    for (const relativePath in master) {
        const smr = master[relativePath];

        for (let i = 0; i < smr.length; i++) {
            const bs = smr[i];
            for (const cm of convertMap.lists) {

                if (cm.originalName == bs) {

                    updateBinding(cm.proxyName, relativePath, i, 100)
                    break;
                }

            }
        }

    }

}

function genetateBindingView() {

    document.querySelector("#bindings").innerHTML = "";

    for (let i = 0; i < binding.length; i++) {

        let element = binding[i];

        let item = document.createElement("div");
        item.classList.add("accordion-item");
        let h2 = document.createElement("h2");
        h2.classList.add("h2");
        let button = document.createElement("button");
        button.setAttribute("type", "button");
        button.setAttribute("data-bs-toggle", "collapse");

        button.setAttribute("data-bs-target", "#bindings" + i);

        button.classList.add("accordion-button", "collapsed");

        let converted = "";

        for (const iterator of convertMap.lists) {
            if (iterator.proxyName == element.blendShapeName) {
                converted = iterator.pmxName;
                break;
            }
        }
        if (converted == "") {
            button.innerText = "このクリップは変換されません" + " ( " + element.blendShapeName + " )";
        } else {
            button.innerText = converted + " ( " + element.blendShapeName + " )";
        }
        let content = document.createElement("div");
        content.setAttribute("bindings-index", i);
        content.id = "bindings" + i;
        content.classList.add("accordion-collapse", "collapse");
        content.setAttribute("data-bs-parent", "#bindings")

        let contentBody = document.createElement("div");
        contentBody.classList.add("accordion-body");

        let deleteButton = document.createElement("button");
        deleteButton.classList.add("btn", "btn-danger");
        deleteButton.innerText = "クリップを削除";
        deleteButton.style.marginBottom = "1rem";

        deleteButton.onclick = () => {
            var res = confirm("このクリップを削除してよろしいですか。");
            if (res) {

                deleteClip(element.blendShapeName);
                return;
            }
            //when cancel
        }

        contentBody.appendChild(deleteButton);

        for (const key in master) {
            let div = document.createElement("div");
            div.classList.add("fw-bold");
            div.innerText = key;
            contentBody.appendChild(div);

            let smr = master[key];

            for (let i = 0; i < smr.length; i++) {
                //i:index, value:name
                const blendshape = smr[i];
                let id = blendshape + i;
                let label = document.createElement("label");
                label.innerText = blendshape;
                label.classList.add("form-label");
                //label.setAttribute("for", id);

                let range = document.createElement("input");
                range.setAttribute("type", "range");
                range.classList.add("form-range");
                range.setAttribute("blendshapename", blendshape);
                range.setAttribute("blendshapeindex", i);
                range.setAttribute("relativepath", key);
                range.setAttribute("bindingname", element.blendShapeName);

                range.setAttribute("min", 0);
                range.setAttribute("max", 100);
                range.oninput = onSliderInput;
                range.value = 0;

                //既存のバインドを読む
                let bindings = element.bindings;
                for (const iterator of bindings) {
                    if (iterator.relativePath == key && iterator.index == i) {
                        range.value = iterator.weight;
                    }
                }

                //range.id = id;
                contentBody.appendChild(label);
                contentBody.appendChild(range);

            }

        }

        item.appendChild(h2);
        h2.appendChild(button);
        item.appendChild(content);
        content.appendChild(contentBody);

        content.addEventListener('hide.bs.collapse', onUnselect);
        content.addEventListener('show.bs.collapse', onSelect);

        document.querySelector("#bindings").appendChild(item);

    }
}




function onUnselect(event) {

    if (event.target.getAttribute("bindings-index") == selectingBindingIndex) {
        selectingBindingIndex = -1;
    }
    updateSelectingToUnity();
}

function onSelect(event) {

    selectingBindingIndex = event.target.getAttribute("bindings-index");
    updateSelectingToUnity();
}

function updateSelectingToUnity() {

    var obj = {
        name: "BindingSelect",
        payload: selectingBindingIndex.toString()
    }
    unitySender.send(JSON.stringify(obj));

}


function onSliderInput(evt) {

    let target = evt.target;
    const bindingName = target.getAttribute("bindingname");
    const relativePath = target.getAttribute("relativepath");
    const index = target.getAttribute("blendshapeindex") * 1;
    const weight = target.value;

    updateBinding(bindingName, relativePath, index, weight);
    sendBindingsToUnity();

}

function updateBinding(bindingName, relativePath, index, weight) {

    if (relativePath) {

        for (const iterator of binding) {

            if (iterator.blendShapeName != bindingName) continue;

            let bindings = iterator.bindings;

            for (const bd of bindings) {
                if (bd.relativePath == relativePath && bd.index == index) {
                    bd.weight = weight;
                    return;
                }
            }
            bindings.push({
                weight: weight,
                index: index,
                relativePath: relativePath
            })

            return;

        }
    }
    //新規追加
    let bindings = [];

    if (relativePath) {
        bindings.push({
            weight: weight,
            index: index,
            relativePath: relativePath
        })
    }
    let obj = { blendShapeName: bindingName, bindings: bindings };
    binding.push(obj);

}

function sendBindingsToUnity() {

    let bindings = JSON.stringify(binding);

    var obj = {
        name: "Bindings",
        payload: bindings
    }
    unitySender.send(JSON.stringify(obj));
}

function deleteClip(clipName) {
    for (let i = 0; i < binding.length; i++) {
        if (binding[i].blendShapeName == clipName) {
            binding.splice(i, 1);
            break;
        }
    }
    selectingBindingIndex = -1;
    updateSelectingToUnity();
    sendBindingsToUnity();
    genetateBindingView();
}


function onAddClip() {

    let body = document.getElementsByTagName("body")[0];
    let dialog = document.createElement("dialog");
    dialog.style.width = "90%";
    dialog.style.height = "90%";

    let select = document.createElement("select");
    select.classList.add("form-select");
    select.setAttribute("size", "20");

    dialog.appendChild(select);

    let btnOk = document.createElement("button");
    btnOk.setAttribute("type", "button");
    btnOk.classList.add("btn", "btn-success");
    btnOk.style.marginTop = "1rem";
    btnOk.innerText = "OK";

    let btnCancel = document.createElement("button");
    btnCancel.setAttribute("type", "button");
    btnCancel.classList.add("btn", "btn-danger");
    btnCancel.style.marginTop = "1rem";
    btnCancel.style.marginRight = "1rem";
    btnCancel.innerText = "キャンセル";

    btnCancel.onclick = () => {
        dialog.close();
        dialog.remove();
    }

    btnOk.onclick = () => {

        if (select.value == "") {
            alert("選択してください。");
            return;
        }

        createPmxClip(select.value);

        dialog.close();
        dialog.remove();
    }


    dialog.appendChild(btnCancel);
    dialog.appendChild(btnOk);

    let selectable = {};

    for (const iterator of convertMap.lists) {
        selectable[iterator.pmxName] = true;
    }


    for (const bs of binding) {
        let name = bs.blendShapeName;
        for (const cm of convertMap.lists) {
            if (name == cm.proxyName) {
                selectable[cm.pmxName] = false;
                break;
            }
        }
    }

    for (const key in selectable) {

        if (selectable[key]) {
            let option = document.createElement("option");
            option.value = key;
            option.innerText = key;
            select.appendChild(option);

        }

    }

    body.appendChild(dialog);
    dialog.showModal();
}


function createPmxClip(pmxName) {

    for (const iterator of convertMap.lists) {
        if (iterator.pmxName == pmxName) {

            updateBinding(iterator.proxyName);
            sendBindingsToUnity();
            genetateBindingView();
            return;
        }
    }

}


function convert() {

    let path = dialog.showOpenDialogSync(null,
        { properties: ["openDirectory", "createDirectory"] }
    )
    if (path && path[0]) {
        var obj = {
            name: "Convert",
            payload: path[0]
        }
        unitySender.send(JSON.stringify(obj));
    }

    let body = document.getElementsByTagName("body")[0];
    let dialogElem = document.createElement("dialog");
    dialogElem.style.width = "90%";
    dialogElem.style.height = "90%";

    let div = document.createElement("div");
    div.style.textAlign = "center";

    dialogElem.appendChild(div);

    let h2 = document.createElement("h2");
    h2.innerText = "変換中";

    div.appendChild(h2);

    let innerDiv = document.createElement("div");
    innerDiv.classList.add("text-success", "spinner-border");

    div.appendChild(innerDiv);


    let buttonDiv = document.createElement("div");
    let button = document.createElement("button");
    button.innerText = "OK";
    button.style.marginTop = "3rem";
    button.classList.add("btn", "btn-secondary", "hidden-part");

    buttonDiv.appendChild(button);
    div.appendChild(buttonDiv);

    body.appendChild(dialogElem);

    dialogElem.showModal();


    unityReceiver.once("Converted", (result) => {

        button.classList.remove("hidden-part");
        h2.innerText = "変換完了";

        innerDiv.classList.add("hidden-part")

        button.onclick = () => {
            location.reload();
        }

    });


}