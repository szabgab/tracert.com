$(document).ready(function(){
	$('.ui.dropdown').dropdown();

	$('#run').on('click', function() {
		alert($('#host').val());
		//alert(this);
	});
});

