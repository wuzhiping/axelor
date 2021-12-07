<%--

    Axelor Business Solutions

    Copyright (C) 2005-2021 Axelor (<http://axelor.com>).

    This program is free software: you can redistribute it and/or  modify
    it under the terms of the GNU Affero General Public License, version 3,
    as published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

--%>
<%@ taglib prefix="x" uri="WEB-INF/axelor.tld" %>
<%@ page language="java" session="true" %>
<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page language="java" session="true" %>
<%@ page import="java.util.Calendar" %>
<%@ page import="java.util.Date" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.Map.Entry"%>
<%@ page import="java.util.Set" %>
<%@ page import="java.util.function.Function"%>
<%@ page import="org.pac4j.http.client.indirect.FormClient" %>
<%@ page import="com.axelor.i18n.I18n" %>
<%@ page import="com.axelor.app.AppSettings" %>
<%@ page import="com.axelor.auth.pac4j.AuthPac4jModule" %>
<%

Function<String, String> T = new Function<String, String>() {
  public String apply(String t) {
    try {
      return I18n.get(t);
    } catch (Exception e) {
      return t; 
    }
  }
};

String errorMsg = T.apply(request.getParameter(FormClient.ERROR_PARAMETER));

String loginTitle = T.apply("Please sign in");
String loginRemember = T.apply("Remember me");
String loginSubmit = T.apply("Log in");

String loginUserName = T.apply("Username");
String loginPassword = T.apply("Password");

String warningBrowser = T.apply("Update your browser!");
String warningAdblock = T.apply("Adblocker detected!");
String warningAdblock2 = T.apply("Please disable the adblocker as it may slow down the application.");

String loginWith = T.apply("Log in with %s");

int year = Calendar.getInstance().get(Calendar.YEAR);
String copyright = String.format("&copy; 2004 - %s LowCode. All Rights Reserved.", year);

String loginHeader = "/login-header.jsp";
if (pageContext.getServletContext().getResource(loginHeader) == null) {
  loginHeader = null;
}

@SuppressWarnings("all")
Map<String, String> tenants = (Map) session.getAttribute("tenantMap");
String tenantId = (String) session.getAttribute("tenantId");

AppSettings settings = AppSettings.get();
String callbackUrl = AuthPac4jModule.getCallbackUrl();

Set<String> centralClients = AuthPac4jModule.getCentralClients();
%>
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta name="google" content="notranslate">
    <link rel="shortcut icon" href="ico/favicon.ico">
    <x:style src="css/application.login.css" />
    <x:script src="js/application.login.js" />
  </head>
  <body>

    <% if (loginHeader != null) { %>
    <jsp:include page="<%= loginHeader %>" />
    <% } %>

    <div class="container-fluid">
      <div class="panel login-panel">
        <div class="panel-header panel-default">
          <img src="img/axelor.png" width="192px">
        </div>

        <div id="error-msg" class="alert alert-block alert-error text-center <%= errorMsg == null ? "hidden" : "" %>">
          <h4><%= errorMsg %></h4>
        </div>

        <% if (!centralClients.isEmpty()) { %>
	      <div id="social-buttons" class="form-fields text-center">
          <% for (String client : centralClients) { %>
            <%
            Map<String, String> info = AuthPac4jModule.getClientInfo(client);
            String title = info.get("title");
            String icon = info.get("icon");
            %>
            <button class="btn" type="button" data-provider="<%= client %>">
              <img class="social-logo <%= client %>" src="<%= icon %>" alt="<%= title %>" title="<%= title %>">
              <div class="social-title"><%= String.format(loginWith, title) %></div>
            </button>
            <% } %>
          </div>
        <% } %>

        <div class="panel-body">
          <form id="login-form" action="<%=callbackUrl%>" method="POST">
            <div class="form-fields">
              <div class="input-prepend">
                <span class="add-on"><i class="fa fa-envelope"></i></span>
                <input type="text" id="usernameId" name="username" placeholder="<%= loginUserName %>" autofocus="autofocus">
              </div>
              <div class="input-prepend">
                <span class="add-on"><i class="fa fa-lock"></i></span>
                <input type="password" id="passwordId" name="password" placeholder="<%= loginPassword %>">
              </div>
              <% if (tenants != null && tenants.size() > 1) { %>
              <div class="input-prepend">
                <span class="add-on"><i class="fa fa-database"></i></span>
                <select name="tenantId">
                <% for (String key : tenants.keySet()) { %>
                	<option value="<%= key %>" <%= (key.equals(tenantId) ? "selected" : "") %>><%= tenants.get(key) %></option>
                <% } %>
                </select>
              </div>
              <% } %>
              <label class="ibox">
                <input type="checkbox" value="rememberMe" name="rememberMe">
                <span class="box"></span>
                <span class="title"><%= loginRemember %></span>
              </label>
              <input type="hidden" name="hash_location" id="hash-location">
            </div>
            <div class="form-footer">
              <button class="btn btn-primary" type="submit"><%= loginSubmit %></button>
            </div>
          </form>
        </div>
      </div>
      <div id="br-warning" class="alert alert-block alert-error hidden">
	  	<h4><%= warningBrowser %></h4>
	  	<ul>
	  		<li>Chrome</li>
	  		<li>Firefox</li>
	  		<li>Safari</li>
	  		<li>IE >= 11</li>
	  	</ul>
	  </div>
	  <div id="ad-warning" class="alert hidden">
	  	<h4><%= warningAdblock %></h4>
	  	<div><%= warningAdblock2 %></div>
	  </div>
    </div>

    <footer class="container-fluid">
      <p class="credit small"><%= copyright %></p>
    </footer>
    
    <div id="adblock"></div>

    <script type="text/javascript">
    $(function () {
	    if (axelor.browser.msie && !axelor.browser.rv) {
	     	$('#br-warning').removeClass('hidden');
	    }
	    if ($('#adblock') === undefined || $('#adblock').is(':hidden')) {
	     	$('#ad-warning').removeClass('hidden');
	    }
	    
	    $("#social-buttons").on('click', 'button', function (e) {
	     var client = $(e.currentTarget).data('provider');
	     window.location.href = './?client_name=' + client
	         + "&hash_location=" + encodeURIComponent(window.location.hash);
	    });

        $('#login-form').submit(function(e) {
          document.getElementById("hash-location").value = window.location.hash;
        });
    });
        </script>
  </body>
</html>
