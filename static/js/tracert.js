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

	$('#resolve').on('click', function() {
		if (! $('#arg').val()) {
			console.log('no');
			$("#needhostname").modal('show');
			return false;
		}
		return true;
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
		var req = $('#form').serialize();
		console.log(req);
		var reswin = window.open("/run?" + req, "ResultWindow","status,resizable=yes,hight=500");
		reswin.focus();
		//alert(this);
	});
});

