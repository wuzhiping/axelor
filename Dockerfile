FROM axelor/aos-preview-app

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo 'Asia/Shanghai' >/etc/timezone

ENV LANG C.UTF-8

EXPOSE 8080

RUN apt-get -q update && \
    apt-get -y --no-install-recommends install curl git vim wget gnupg software-properties-common unzip && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x219BD9C9 && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /app
WORKDIR /app

#
#RUN wget https://downloads.gradle-dn.com/distributions/gradle-5.6.4-bin.zip
#RUN mkdir /opt/gradle
#RUN unzip -d /opt/gradle gradle-5.6.4-bin.zip
#RUN export PATH=$PATH:/opt/gradle/gradle-5.6.4/bin
#RUN chmod +x /opt/gradle/gradle-5.6.4/bin/gradle
#RUN /opt/gradle/gradle-5.6.4/bin/gradle -version

#adk i18n zh
RUN git clone https://github.com/axelor/axelor-open-platform.git
WORKDIR /app/axelor-open-platform
COPY ./adk/build.gradle       /app/axelor-open-platform/build.gradle
COPY ./adk/version.gradle     /app/axelor-open-platform/version.gradle
COPY ./adk/gradle/libs.gradle /app/axelor-open-platform/gradle/libs.gradle

COPY ./adk/axelor-web/src/main/webapp/img/axelor.png           /app/axelor-open-platform/axelor-web/src/main/webapp/img/axelor.png
COPY ./adk/axelor-web/src/main/webapp/index.jsp                /app/axelor-open-platform/axelor-web/src/main/webapp/index.jsp
COPY ./adk/axelor-web/src/main/webapp/login.jsp                /app/axelor-open-platform/axelor-web/src/main/webapp/login.jsp
COPY ./adk/axelor-core/src/main/resources/i18n/messages_zh.csv /app/axelor-open-platform/axelor-core/src/main/resources/i18n/messages_zh.csv

RUN git status .
RUN ./gradlew -x build publishToMavenLocal

RUN find ~/.m2/repository/ -name "*.jar"
#RUN /opt/gradle/gradle-5.6.4/bin/gradle install

WORKDIR /app
RUN git clone https://github.com/axelor/open-suite-webapp.git axelor-erp
RUN sed -e 's|git@github.com:|https://github.com/|' -i axelor-erp/.gitmodules
WORKDIR /app/axelor-erp
RUN git checkout master
RUN git submodule sync
RUN git submodule init
RUN git submodule update
RUN git submodule foreach git checkout master
RUN git submodule foreach git pull origin master

COPY application-mysql.properties /app/axelor-erp/src/main/resources/application.properties
COPY ./abs/build.gradle /app/axelor-erp/build.gradle

COPY ./adk/axelor-web/src/main/webapp/img/axelor.png          /app/axelor-erp/src/main/webapp/img/axelor.png

COPY ./abs/axelor-base/src/main/resources/views/Selects.xml   /app/axelor-erp/modules/axelor-open-suite/axelor-base/src/main/resources/views/Selects.xml
COPY ./abs/axelor-web/src/main/resources/i18n/messages_zh.csv /app/axelor-erp/modules/axelor-open-suite/axelor-web/src/main/resources/i18n/messages_zh.csv 

RUN git status .

#
COPY ./modules/phx-mro /app/axelor-erp/modules/axelor-open-suite/phx-mro

RUN ./gradlew -x test build

#deploy
RUN cp /app/axelor-erp/src/main/resources/application.properties /usr/local/tomcat/application.properties

RUN rm -R /usr/local/tomcat/webapps/ROOT
WORKDIR /usr/local/tomcat/webapps
RUN cp /app/axelor-erp/build/libs/axelor-erp-*.war /usr/local/tomcat/webapps/ROOT.war
#RUN chown tomcat:tomcat ROOT.war

#RUN unzip ROOT.war -d ROOT

COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
