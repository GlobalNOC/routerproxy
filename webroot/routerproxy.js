
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
    var url = "?method=device&device=" + obj.value;
    
    var req = new XMLHttpRequest();
    req.onreadystatechange = function() {
        if (req.readyState == 4 && req.status == 200) {
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
            var menus = document.getElementsByClassName('menu-table');
            for (i = 0; i < menus.length; i++) {
                menus[i].style.display = 'none';
            }

            if (data.enable_menu == 1) {
                var ul = document.getElementById(data.type + '_menu');
                if (ul != null) { // Not all device types have a menu.
                    ul.style.display = 'table';
                }
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
    var i;

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
    var select = document.getElementById("host_command_select");
    return select.options[select.selectedIndex].value;
}

function showMessage(s) {
    var wrapper = document.getElementById("result");
    wrapper.style.display = 'block';

    var title = document.getElementById("result_title");
    title.innerHTML = s;

    var pre = document.getElementById("result_pre");
    pre.innerHTML = '';

    var tbl = document.getElementById("menu_result");
    tbl.style.display = 'none';
}

function submitCommand() {
    var d = selectedDevice();
    var url = '?method=submit';
    url = url + '&device=' + d;
    url = url + '&command=' + selectedCommand();
    url = url + '&menu=0';

    showMessage('Waiting on: ' + d);

    var args = document.getElementById("host_command_text");
    if (args != null && args != '') {
        url = url + '&arguments=' + args.value;
    }
    
    var req = new XMLHttpRequest();
    req.onreadystatechange = function() {
        if (req.readyState == 4 && req.status == 200) {
            var wrapper = document.getElementById("result");
            wrapper.style.display = 'block';
            
            var title = document.getElementById("result_title");
            title.innerHTML = 'Response from: ' + d;

            var pre = document.getElementById("result_pre");
            pre.innerHTML = req.responseText;

            var tbl = document.getElementById("menu_result");
            tbl.style.display = 'none';
            tbl.innerHTML = '';
        } else if (req.readyState == 4) {
            showMessage('Error: ' + req.responseText);
        }
    };

    req.open("GET", url, true);
    req.timeout = 60000;
    req.ontimeout = function() { showMessage('Request timeout: ' + d); };
    req.send(null);

    return false;
}

function submitMenuCommand(command) {
    var d = selectedDevice();
    var url = '?method=submit';
    url = url + '&device=' + d;
    url = url + '&command=' + command;
    url = url + '&menu=1';

    showMessage('Waiting on: ' + d);

    var req = new XMLHttpRequest();
    req.onreadystatechange = function() {
        if (req.readyState == 4 && req.status == 200) {
            var wrapper = document.getElementById("result");
            wrapper.style.display = 'none';

            var pre = document.getElementById("result_pre");
            pre.innerHTML = '';

            var tbl = document.getElementById("menu_result");
            tbl.style.display = 'block';
            tbl.innerHTML = req.responseText;
        } else if (req.readyState == 4) {
            showMessage('Error: ' + req.responseText);
        }
    };

    req.open("GET", url, true);
    req.timeout = 60000;
    req.ontimeout = function() { showMessage('Request timeout: ' + d); };
    req.send(null);    
}
