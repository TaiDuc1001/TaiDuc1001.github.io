const deg = 6;
const hr = document.querySelector('#hr');
const mn = document.querySelector('#mn');
const sc = document.querySelector('#sc');

const hr_gl = document.querySelector('#hr_gl');
const mn_gl = document.querySelector('#mn_gl');
const sc_gl = document.querySelector('#sc_gl');

// let menu_btn = document.querySelector("#menu-button");

// menu_btn.onClick = function(){
//     sideBar.classList.toggle("active");
// }


setInterval(
    () => {

        let day = new Date();
        let hh = day.getHours() * 30;
        let mm = day.getMinutes() * deg;
        let ss = day.getSeconds() * deg;

        hr.style.transform = `rotateZ(${(hh) + (mm / 12)}deg)`;
        mn.style.transform = `rotateZ(${mm}deg)`;
        sc.style.transform = `rotateZ(${ss}deg)`;

        hr_gl.style.transform = `rotateZ(${(hh) + (mm / 12)}deg)`;
        mn_gl.style.transform = `rotateZ(${mm}deg)`;
        sc_gl.style.transform = `rotateZ(${ss}deg)`;
    }
)


function popupToggle() {
    const popup = document.getElementById('popup');
    popup.classList.toggle('active');
}
function sideBarToggle() {
    // const sideBar = document.getElementById('sidebar');
    let sideBar = document.querySelector(".sidebar");

    sideBar.classList.toggle('active');
}