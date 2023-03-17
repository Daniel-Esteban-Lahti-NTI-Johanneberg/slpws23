$(document).ready(function(){
    var countDownDate = new Date().setHours(24,0,0,0);
    var countdown = setInterval(function(){
        var now = new Date().getTime();
        var distance = countDownDate - now;
        var hours = Math.floor((distance % (1000*60*60*24))/(1000*60*60));
        var minutes = Math.floor((distance % (1000*60*60))/(1000*60));
        var seconds = Math.floor((distance % (1000*60))/1000);
        document.getElementById("countdown").innerHTML = hours + "h " + minutes + "m " + seconds + "s "
        if (distance < 0){
            clearInterval(countdown);
            $.post('/prompts/update', function() {
                location.reload();
            });
        }
    }, 1000);
});