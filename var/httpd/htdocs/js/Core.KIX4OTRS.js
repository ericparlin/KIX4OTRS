// --
// Core.KIX4OTRS.js - provides the special common functions for KIX4OTRS
// Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
//
// written/edited by:
//   Rene(dot)Boehm(at)cape(dash)it.de
//   Dorothea(dot)Doerffel(at)cape(dash)it.de
// --
// $Id$
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS
 * @description This namespace contains the special module functions for
 *              KIX4OTRS
 */
Core.KIX4OTRS = (function(TargetNS) {

    TargetNS.GetWidgetPopupPosition = function(Element, Event) {
        if (!$(Element).find('.WidgetPopup').length) {
            return {
                Left : 0,
                Top : 0
            };
        }

        var $Details = $(Element).find('.WidgetPopup'),
            MousePositionLeft = parseInt(Event.pageX, 10),
            MousePositionTop = parseInt(Event.pageY, 10),
            DetailHeight = $Details.height(),
            DetailWidth = $Details.width(),
            DetailPositionLeft = MousePositionLeft - 30,
            DetailPositionTop = MousePositionTop + 30;

        if (DetailPositionLeft + DetailWidth + 15 > $(window).width()) {
            DetailPositionLeft = DetailPositionLeft - DetailWidth - 30;
        }
        if (DetailPositionTop + DetailHeight + 15 > $(window).height()) {
            DetailPositionTop = DetailPositionTop - DetailHeight - 30;
        }
        if (DetailPositionTop < 0) {
            DetailPositionTop = MousePositionTop + 30;
        }

        return {
            Left : DetailPositionLeft,
            Top : DetailPositionTop
        };
    }

    TargetNS.SelectLinkedObjects = function(Action, Language) {

        var $Tabs = $("[id^=ui-tabs-]"),
            $CurrentTab;

        $.each($Tabs, function() {
            if ($(this).attr('aria-expanded') == 'true') {
                $CurrentTab = $(this);
            }
        });

        // bind delete button
        $CurrentTab.find('.Primary').bind('click', function() {
            var $SelectedLinks = $(this).parent().parent().find(':checked');

            if ($SelectedLinks.length == 0) {
                return;
            }

            // ask the user
            var Type = Core.Config.Get('Question');
            var Question = '<p class="Spacing">' + Core.Config.Get('DeleteLinksQuestion') + '</p>';
            var Yes = Core.Config.Get('Yes');
            var No = Core.Config.Get('No');

            Core.KIX4OTRS.Dialog.ShowQuestion(Type, Question, Yes, function() {
                // Yes - delete links
                Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                $SelectedLinks.each(function() {
                    var LinkDef = $(this).val().split(/::/), URL = 'Action=AgentLinkObjectUtils;Subaction=DeleteLink;IsAJAXCall=1;OrgAction=' + Action
                        + ';SourceObject=' + LinkDef[0] + ';SourceKey=' + LinkDef[1] + ';TargetObject=' + LinkDef[2] + ';TargetKey=' + LinkDef[3]
                        + ';LinkType=' + LinkDef[4];

                    // synchronous call
                    Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'text', false);

                    // reload tab - this is just a little hack but it works ;)
                    window.location = $CurrentTab;
                    location.reload();
                });
            }, No, function() {
                // No
                Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
            });
        });
    }

    /**
     * @function Resize a popup and store the new size of the popup after
     *           resizing
     * @param {String}
     *            calling action
     */

    TargetNS.ResizePopup = function(Action) {

        var PopupWidth,
            PopupHeight,
            Start = 1,
            ResizeDone = 0,
            URL = Core.Config.Get('Baselink');

        if (window.name.match(/OTRSPopup_.+/) && window.opener !== null) {
            if (Start) {
                // get data
                Data = {
                    Action : 'PopupSize',
                    Subaction : 'GetPopupSize',
                    CallingAction : Action
                };

                // get user preferences width and height of the popup window
                Core.AJAX.FunctionCall(URL, Data, function(Result) {
                    $.each(Result, function() {
                        PopupWidth = this.Width;
                        PopupHeight = this.Height;
                        if (PopupHeight && PopupWidth) {
                            window.resizeTo(PopupWidth, PopupHeight);
                            ResizeDone = 1;
                        }
                    });
                });

                if (!ResizeDone) {
                    Start = 0;
                }

            }

            // get end of resizing
            $(window).resize(function() {
                if (this.resizeTO) {
                    clearTimeout(this.resizeTO);
                }
                this.resizeTO = setTimeout(function() {
                    $(this).trigger('resizeEnd');
                }, 500);
            });

            // save new size every time the size has changed
            $(window).bind('resizeEnd', function() {

                if (!Start) {
                    var Height = window.outerHeight, Width = window.outerWidth;

                    var URL = Core.Config.Get('Baselink'), Data = {
                        Action : 'PopupSize',
                        Subaction : 'UpdatePopupSize',
                        CallingAction : Action,
                        Width : Width,
                        Height : Height
                    };

                    Core.AJAX.FunctionCall(URL, Data, function() {}, 'text');
                } else {
                    Start = 0;
                }
            });
        }
    }

    /**
     * @function
     * @private
     * @description Load a draft
     */

    TargetNS.LoadDraft = function(Action, TicketID, Question) {
        // if not given, determine Action

        if ( !Action )
            Action = $('#SaveAsDraft').closest('form').children('input[name=Action]').val();

        // if not given, determine TicketID
        if ( !TicketID ) {
            var ID = $('#SaveAsDraft').closest('form').children('input[name=TicketID]').val();
            if ( ID && ID != '' ) {
                TicketID = $('#SaveAsDraft').closest('form').children('input[name=TicketID]').val();
            }
            else {
                TicketID = 0;
            }
        }

        // no action and TicketID - return
        if ( !Action )
            return;

        // get saved form
        var URL = Core.Config.Get('Baselink'),
            Data = {
            Action : 'SaveAsDraftAJAXHandler',
            Subaction : 'GetFormContent',
            CallingAction : Action,
            TicketID : TicketID
            },
            ContentExists = false,
            Content;

        Core.AJAX.FunctionCall(URL, Data, function(Result) {
            Content = Result;
            $.each(Result, function() {
                if (this.Label == 'Body' && window.CKEDITOR && CKEDITOR.instances.RichText) {
                    ContentExists = ContentExists || (this.Value != '');
                } else {
                    ContentExists = ContentExists || (($('#' + this.Label).length) && (this.Value != ''));
                }
            });

            // if form exists, ask to use or to delete it
            if (ContentExists === true) {
                if (!Question)
                    Question = Core.Config.Get('LoadDraftMsg');

                Core.KIX4OTRS.Dialog.ShowQuestion(Core.Config.Get('Question'), Question, Core.Config.Get('Yes'), function() {
                    // Yes - load form content from WebUpload Cache
                    Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    $.each(Content, function() {
                        if ($('#' + this.Label).length) {
                            $('#' + this.Label).val(this.Value);
                        } else if (this.Label == 'Body' && window.CKEDITOR && CKEDITOR.instances.RichText) {
                            CKEDITOR.instances.RichText.setData(this.Value, function() {
                                this.updateElement();   // sync data to base element
                            });
                        }
                        else if (this.Label == 'Body' && !$('#' + this.Label).length && $('#RichText').length) {
                            $('#RichText').val(this.Value);
                        }
                    });
                }, Core.Config.Get('Delete'), function() {
                    DeleteDraft(Action, TicketID);
                });
            }
        }, 'json');
    }

    /**
     * @function
     * @private
     * @description Saves form content as draft
     */

    function SaveDraft() {
        var $Form = $('#SaveAsDraft').closest('form'),
            Data = Core.AJAX.SerializeForm($Form);

        // some special handling for CKEDITOR
        if ( typeof(CKEDITOR) !== "undefined" && CKEDITOR.instances.RichText) {
            Data += encodeURIComponent('Body') + '=' + encodeURIComponent(CKEDITOR.instances.RichText.getData() || '');
        }

        // create URL
        Data = Data.replace(/Action=/g, 'CallingAction=');
        Data = Data.replace(/Subaction=(.*?)\;/g, '');
        URL = 'Action=SaveAsDraftAJAXHandler;Subaction=SaveFormContent;' + Data;

        // save content and do not submit form
        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'json');
        return false;
    }

    /**
     * @function
     * @private
     * @description delete a saved draft
     */

    function DeleteDraft(Action, TicketID) {

        // No - delete form content from WebUpload Cache
        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
        URL = 'Action=SaveAsDraftAJAXHandler;Subaction=DeleteFormContent;CallingAction=' + Action + ';TicketID=' + TicketID;
        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'json');
    }

    /**
     * @function Saves form content as draft, deletes old drafts
     * @param {String}
     *            calling action
     * @param {String}
     *            dialog question
     * @param {String}
     *            save interval in milliseconds
     */

    TargetNS.InitSaveAsDraft = function(Action, Question, Interval) {
        // get form
        var $Form = $('#SaveAsDraft').closest('form'),
            ActiveInterval,
            Attributes = Core.Config.Get('Attributes').split(","),
            AttributeString = '',
            TicketID = $Form.find('input[name="TicketID"]').val() || '';

        // on submit delete saved form content and stop timer
        $Form.submit(function() {
            clearInterval(ActiveInterval);
            URL = 'Action=SaveAsDraftAJAXHandler;Subaction=DeleteFormContent;CallingAction=' + Action + ';TicketID=' + TicketID;
            Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'json');
        });

        // delete draft when clicking on Cancel link
        $('div.Header a.CancelClosePopup').bind('click', function() {
            DeleteDraft(Action, TicketID);
        });

        // save content after clicking the "Save As Draft" button
        $(document).on('click', '#SaveAsDraft', function(event) {
            SaveDraft();
        });

        // reset intervall if keypressed in RichTextEditor
        if (window.CKEDITOR && CKEDITOR.instances.RichText) {
            CKEDITOR.instances.RichText.on('key', function() {
                window.clearTimeout(ActiveInterval);
                ActiveInterval = window.setTimeout(function() {
                    SaveDraft();
                }, Interval);
            });
        }

        // reset intervall if keypressed in other input fields
        $.each(Attributes, function(Key, Value) {
            Attributes[Key] = '#' + Value;
        });
        AttributeString = Attributes.join(', ');
        $(AttributeString).bind('keydown', function(event) {
            window.clearTimeout(ActiveInterval);
            ActiveInterval = window.setTimeout(function() {
                SaveDraft();
            }, Interval);
        });

        // show dialog on load if saved form is available
        $(window).load(function() {
            TargetNS.LoadDraft(Action, TicketID, Question);
        });

        // initial call to check for loadable content (necessary for Ticket Tabs)
        TargetNS.LoadDraft(Action, TicketID, Question);
    }

    /**
     * @function Saves form content as draft, deletes old drafts
     * @param {String}
     *            calling action
     * @param {String}
     *            dialog question
     * @param {String}
     *            save interval in milliseconds
     */

    TargetNS.SaveAsDraft = function(Action, Question, Interval) {
        // get form
        var $Form = $('#SaveAsDraft').closest('form'),
            ActiveInterval,
            Attributes = Core.Config.Get('Attributes').split(","),
            AttributeString = '',
            TicketID = $Form.find('input[name="TicketID"]').val() || '';

        // on submit delete saved form content and stop timer
        $Form.submit(function() {
            clearInterval(ActiveInterval);
            URL = 'Action=SaveAsDraftAJAXHandler;Subaction=DeleteFormContent;CallingAction=' + Action + ';TicketID=' + TicketID;
            Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'json');
        });

        // delete draft when clicking on Cancel link
        $('div.Header a.CancelClosePopup').bind('click', function() {
            DeleteDraft(Action, TicketID);
        });

        // save content after clicking the "Save As Draft" button
        $('#SaveAsDraft').on('click', function(event) {
            SaveContent();
        });

        // reset intervall if keypressed in RichTextEditor
        if (window.CKEDITOR && CKEDITOR.instances.RichText) {
            CKEDITOR.instances.RichText.on('key', function() {
                window.clearTimeout(ActiveInterval);
                ActiveInterval = window.setTimeout(function() {
                    SaveContent();
                }, Interval);
            });
        }

        // reset intervall if keypressed in other input fields
        $.each(Attributes, function(Key, Value) {
            Attributes[Key] = '#' + Value;
        });
        AttributeString = Attributes.join(', ');
        $(AttributeString).bind('keydown', function(event) {
            window.clearTimeout(ActiveInterval);
            ActiveInterval = window.setTimeout(function() {
                SaveContent();
            }, Interval);
        });

        // show dialog on load if saved form is available
        $(window).load(function() {
            // get saved form
            var URL = Core.Config.Get('Baselink'),
                Data = {
                    Action : 'SaveAsDraftAJAXHandler',
                    Subaction : 'GetFormContent',
                    CallingAction : Action,
                    TicketID : TicketID
                },
                ContentExists = false,
                Content;

            Core.AJAX.FunctionCall(URL, Data, function(Result) {
                Content = Result;
                $.each(Result, function() {
                    if (this.Label == 'Body' && window.CKEDITOR && CKEDITOR.instances.RichText) {
                        ContentExists = ContentExists || (this.Value != '');
                    } else {
                        ContentExists = ContentExists || (($('#' + this.Label).length) && (this.Value != ''));
                    }
                });

                // if form exists, ask to use or to delete it
                if (ContentExists === true) {
                    Core.KIX4OTRS.Dialog.ShowQuestion(Core.Config.Get('Question'), Question, Core.Config.Get('Yes'), function() {
                        // Yes - load form content from WebUpload Cache
                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                        $.each(Content, function() {
                            if ($('#' + this.Label).length) {
                                $('#' + this.Label).val(this.Value);
                            } else if (this.Label == 'Body' && window.CKEDITOR && CKEDITOR.instances.RichText) {
                                CKEDITOR.instances.RichText.setData(this.Value);
                            }
                        });
                    }, Core.Config.Get('Delete'), function() {
                        DeleteDraft(Action, TicketID);
                    });
                }
            }, 'json');
        });
    }

    /**
     * @function
     * @return nothing
     *      Sets queue if service assigned queue defined
     */

    TargetNS.ServiceAssignedQueue = function() {
        var $Form       = $('#ServiceID').closest('form'),
            $Action     = $Form.find('input[name="Action"]'),
            Selected    = "",
            ActionValue = $Action.val();

        if ( $("#ServiceID").val() != "" ) {
            // set action for AJAX handler
            $Action.val('ServiceAssignedQueueAJAXHandler');

            // get new queue id to set
            Core.AJAX.FunctionCall(Core.Config.Get('Baselink'),Core.AJAX.SerializeForm($Form),function(Response){

                // if queue id given
                if ( Response.AssignedQueue != 0 ) {
                    // set queue id for note, close, etc.
                    if ( $("#NewQueueID").length ) {
                        $("#NewQueueID").val(Response.AssignedQueue);
                    }
                    // set queue id for phone, email, etc.
                    else if ( $("#Dest").length ) {
                        $("#Dest").find("option").each(function(Key,Value){
                            var Expression = "^"+Response.AssignedQueue+"\\|+";
                                CompareRegExp = new RegExp(Expression, "i");
                            if ( CompareRegExp.test($(this).val()) ) {

                                // set new queue
                                $("#Dest").attr($(this).val());

                                // prepare to set new signature
                                var Dest = $("#Dest").val(),
                                    Signature,
                                    OldSignature = $("#Signature").length > 0 ? $("#Signature").attr('src') : '',
                                    OldSignatureArray = OldSignature.split(";"),
                                    NewSignatureArray = new Array();

                                // use old values except Dest
                                $.each(OldSignatureArray,function(Key,Value){
                                    if ( Value.match(/^(?!Dest\=).+/)) {
                                        NewSignatureArray.push(Value);
                                    }
                                });

                                // push new queue value
                                NewSignatureArray.push("Dest="+Dest);
                                Signature = NewSignatureArray.join(";");

                                // set signature if given
                                if ( Response.Signature != '' ) {
                                    $("#Signature").html(Response.Signature);
                                }
                            }
                        });
                    }
                }

                // reset action
                $Action.val(ActionValue);
            });
        }
    }

    return TargetNS;
}(Core.KIX4OTRS || {}));
