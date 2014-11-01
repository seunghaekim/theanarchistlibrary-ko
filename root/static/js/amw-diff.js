$('#reload').click(function() { location.reload() });

function amw_diff_display (diffs) {
    var html = [];
    var pattern_amp = /&/g;
    var pattern_lt = /</g;
    var pattern_gt = />/g;
    var pattern_para = /\n/g;
    for (var x = 0; x < diffs.length; x++) {
        var op = diffs[x][0];    // Operation (insert, delete, equal)
        var data = diffs[x][1];  // Text of change.
        var text = data.replace(pattern_amp, '&amp;').replace(pattern_lt, '&lt;')
            .replace(pattern_gt, '&gt;').replace(pattern_para, '&para;<br>');
        switch (op) {
        case DIFF_INSERT:
            html[x] = '<ins class="amw-diff-insertion">' + text + '</ins>';
            break;
        case DIFF_DELETE:
            html[x] = '<del class="amw-diff-deletion">' + text + '</del>';
            break;
        case DIFF_EQUAL:
            var context = text;
            if (text.match(/<br>/)) {
                var context_lines = text.split('&para;<br>');
                if (context_lines.length > 6) {
                    var last_index = context_lines.length - 1;
                    var filtered_context = [ context_lines[0],
                                             '&para;<br>',
                                             context_lines[1],
                                             '&para;<br>',
                                             '<br>[...]<br><br>',
                                             context_lines[last_index - 1],
                                             '&para;<br>',
                                             context_lines[last_index] ];
                    context = filtered_context.join('');
                }
            }
            html[x] = '<span class="amw-diff-context">' + context + '</span>';
            break;
        }
    }
    return html.join('');
}

var dmp = new diff_match_patch();
$(document).ready(function () {
    var text1 = $('#original').val();
    var text2 = $('#current').val();
    dmp.Diff_Timeout = 0;
    dmp.Diff_EditCost = 4;
    var ms_start = (new Date()).getTime();
    var d = dmp.diff_main(text1, text2);
    var ms_end = (new Date()).getTime();
    dmp.diff_cleanupSemantic(d);
    var ds = amw_diff_display(d);
    $('#outputdiv').html(ds);
    $('#timing').text((ms_end - ms_start) / 1000 + 's');
});
