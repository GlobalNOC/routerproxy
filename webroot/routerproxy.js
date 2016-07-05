
function toggle(id) {
    var object = document.getElementById(id);
    var currentDisplay = object.style.display;
    
    if (currentDisplay == "none") {
        object.style.display = 'table';
    } else {
        object.style.display = "none";
    }
}

function loadCommands(obj) {
    var address = obj.value;
    var url = "?method=device&address=" + address;
    
    var req = new XMLHttpRequest();
    req.onreadystatechange = function() {
        if (req.readyState == 4) { // && req.status == 200) {
            var select = document.getElementById("host_command_select");
            var i;
            for (i = select.options.length -1; i >= 0; i--) {
                select.remove(i);
            }
            
            var data = JSON.parse(req.responseText);
            for (i = data.commands.length - 1; i >= 0; i--) {
                var opt = document.createElement("option");
                opt.text = data.commands[i];
                opt.value = data.commands[i];
                select.add(opt);
            }

            // Clear existing menus
            const menus = document.getElementsByClassName('menu-table');
            for (let i = 0; i < menus.length; i++) {
                menus[i].style.display = 'none';
            }

            if (data.enable_menu == 1) {
                const ul = document.getElementById(data.type + '_menu');
                ul.style.display = 'table';
            }
        }
    }
    req.open("GET", url, true);
    req.send(null);
}

// Return the value of the selected device's radio button, or null if
// one cannot be found.
function selectedDevice() {
    var devices = document.getElementsByName("host_radio");

    for (i = 0; devices.length > i; i++) {
        if (devices[i].checked) {
            return devices[i].value;
        }
    }

    console.log("No device's radio button is currently selected.");
    return null;
}

// Return the value of the currently selected command, or null if one is
// not selected.
function selectedCommand() {
    const select = document.getElementById("host_command_select");
    return select.options[select.selectedIndex].value;
}

function submitCommand() {
    const d = selectedDevice();
    let url = '?method=submit';
    url = url + '&device='  + d;
    url = url + '&command=' + selectedCommand();
    url = url + '&menu=0';

    const args = document.getElementById("host_command_text");
    if (args != null && args != '') {
        url = url + '&arguments=' + args.value;
    }
    
    const req = new XMLHttpRequest();
    req.onreadystatechange = function() {
        // TODO Fix http response status code.
        if (req.readyState == 4) { // && req.status == 200) {
            const wrapper = document.getElementById("result");
            wrapper.style.display = 'block';
            
            const title = document.getElementById("result_title");
            title.innerHTML = 'Response from: ' + d;

            const pre = document.getElementById("result_pre");
            pre.innerHTML = req.responseText;

            const tbl = document.getElementById("menu_result");
            tbl.style.display = 'none';
            tbl.innerHTML = '';
        }
    }

    req.open("GET", url, true);
    req.send(null);
}

function submitMenuCommand(command) {
    let url = '?method=submit';
    url = url + '&device=' + selectedDevice();
    url = url + '&command=' + command;
    url = url + '&menu=1';

    const req = new XMLHttpRequest();
    req.onreadystatechange = function() {
        // TODO Fix http response status code.
        if (req.readyState == 4) { // && req.status == 200) {
            const wrapper = document.getElementById("result");
            wrapper.style.display = 'none';

            const pre = document.getElementById("result_pre");
            pre.innerHTML = '';

            const tbl = document.getElementById("menu_result");
            tbl.style.display = 'block';
            tbl.innerHTML = req.responseText;
        }
    }

    req.open("GET", url, true);
    req.send(null);    
}
