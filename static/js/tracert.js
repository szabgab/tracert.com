$(document).ready(function(){
	$('.ui.dropdown').dropdown();

	var gws = 0;
	$('.gw').on('click', function() {
		//console.log( $(this).is(':checked') );
		if ($(this).is(':checked') ) {
			if (gws >=3) {
				$('#toomany').modal('show');
				$(this).prop('checked', false);
			}
			gws++;
		} else {
			gws--;
		}
	});

	$('#run').on('click', function() {
		//alert($('#host').val());

		if (gws == 0) {
			$('#zero').modal('show');
		}

		if (gws > 3) {
			$('#toomany').modal('show');
		}

		//$('.gw').each(function(idx) {
			//console.log(idx);
			//console.log($(this).attr('value'));
			//console.log($(this).is(':checked'));
		//	if ($(this).is(':checked')) {
		//		gws++;
		//	}
		//});
		console.log($('#form').serialize());
		console.log(gws);
			//var reswin = window.open("", "ResultWindow","status,resizable=yes,hight=500");
			//reswin.focus();
		//alert(this);
	});
});

