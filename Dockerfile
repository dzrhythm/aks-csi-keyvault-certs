FROM mcr.microsoft.com/dotnet/aspnet:6.0-bullseye-slim as base
EXPOSE 8080
EXPOSE 8443
ENV ASPNETCORE_URLS "https://+:8443;http://+:8080"

FROM mcr.microsoft.com/dotnet/sdk:6.0-bullseye-slim AS build
WORKDIR /source

# copy csproj and restore as distinct layers
COPY aspnetapp/*.csproj ./aspnetapp/
RUN dotnet restore aspnetapp/*.csproj

# copy everything else and build app
COPY aspnetapp/. ./aspnetapp/
WORKDIR /source/aspnetapp
RUN dotnet publish -c release -o /app --no-restore

# final stage/image
FROM base as final
WORKDIR /app
COPY --from=build /app ./
ENTRYPOINT ["dotnet", "aspnetapp.dll"]