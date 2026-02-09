FROM public.ecr.aws/lambda/python:3.12

# Install git and unzip (curl-minimal is already present in base image)
# hadolint ignore=DL3041
RUN dnf install -y git unzip && dnf clean all

# Install Terraform
ARG TERRAFORM_VERSION=1.14.0
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
      -o /tmp/terraform.zip && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    rm /tmp/terraform.zip && \
    chmod +x /usr/local/bin/terraform

# Install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r "${LAMBDA_TASK_ROOT}/requirements.txt"

# Copy handler
COPY handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.lambda_handler"]
