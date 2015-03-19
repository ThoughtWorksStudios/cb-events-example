# cb-events-example

This example usage of the Mingle Events gem was tested on a project built from the Scrum template. The only modification to the project was renaming Status => Delivery Status. Generating data involved simply changing this property on Story type cards.

All connection config can be stored in a YAML config file. See the `local.yml` file for an example.

Running this example is simple.

```
gem install bundler
bundle

# replace local.yml with a config file that works for you. this one hits localhost
ruby story_delivery_status.rb local.yml