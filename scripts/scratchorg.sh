# UNMANAGED for use with scratch org

# Install scriptecho "Cleaning previous scratch org..."
echo "Cleaning previous scratch org..."
sfdx force:org:delete -p -u CampaignMembers

echo "Clearing namespace"
#sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"\"|" sfdx-project.json

echo "Creating new scratch org"
sfdx force:org:create --definitionfile config/project-scratch-def.json --setalias CampaignMembers --nonamespace --setdefaultusername --noancestors --durationdays 14

# For use with namespaced scratch org in package development process
echo "Deploying metadata"
sfdx force:source:deploy -p triggerhandler --tracksource
sfdx force:source:deploy -p force-app --tracksource
sfdx force:source:deploy -p unpackaged --tracksource

echo "opening org"
sfdx force:org:open